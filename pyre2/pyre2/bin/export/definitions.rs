/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

use std::cmp;

use ruff_python_ast::name::Name;
use ruff_python_ast::ExceptHandler;
use ruff_python_ast::Expr;
use ruff_python_ast::ExprAttribute;
use ruff_python_ast::ExprCall;
use ruff_python_ast::ExprName;
use ruff_python_ast::Identifier;
use ruff_python_ast::Operator;
use ruff_python_ast::Pattern;
use ruff_python_ast::Stmt;
use ruff_python_ast::StmtExpr;
use ruff_text_size::TextRange;
use starlark_map::small_map::Entry;
use starlark_map::small_map::SmallMap;

use crate::ast::Ast;
use crate::config::Config;
use crate::dunder;
use crate::module::module_info::ModuleStyle;
use crate::module::module_name::ModuleName;
use crate::visitors::Visitors;

/// How a name is defined.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum DefinitionStyle {
    /// Defined in this module, e.g. `x = 1` or `def x(): ...`
    Local,
    /// Imported with an alias, e.g. `from x import y as z`
    ImportAs,
    /// Imported with an alias, where the alias is identical, e.g. `from x import y as y`
    ImportAsEq,
    /// Imported from another module, e.g. `from x import y`
    Import,
    /// Imported directly, e.g. `import x` or `import x.y` (both of which add `x`)
    ImportModule,
}

/// Find the definitions available in a scope. Does not traverse inside classes/functions,
/// since they are separate scopes.
#[derive(Debug, Clone, Default)]
pub struct Definitions {
    /// All the things defined in this module, along with a position pointing at the name.
    /// While the range will be a place it is defined, there is no guarantee it is the first/last or otherwise.
    /// If the definition occurs multiple times, the lowest `DefinitionStyle`` is used (e.g. prefer `Local`).
    /// The number is the distinct times this variable was defined.
    pub definitions: SmallMap<Name, (TextRange, DefinitionStyle, usize)>,
    /// All the modules that are imported with `from x import *`.
    pub import_all: SmallMap<ModuleName, TextRange>,
    /// The `__all__` variable contents.
    pub dunder_all: Vec<DunderAllEntry>,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum DunderAllEntry {
    Name(TextRange, Name),
    Module(TextRange, ModuleName),
    // We have to have this explicitly, as you might remove something in a Module
    Remove(TextRange, Name),
}

impl DunderAllEntry {
    fn is_all(x: &Expr) -> bool {
        matches!(x, Expr::Name(ExprName { id, .. }) if id == &dunder::ALL)
    }

    fn as_list(x: &Expr) -> Vec<Self> {
        match x {
            Expr::List(x) => x.elts.iter().filter_map(DunderAllEntry::as_item).collect(),
            Expr::Tuple(x) => x.elts.iter().filter_map(DunderAllEntry::as_item).collect(),
            Expr::Attribute(ExprAttribute {
                value: box Expr::Name(name),
                attr,
                ..
            }) if attr.id == dunder::ALL => {
                vec![DunderAllEntry::Module(
                    name.range,
                    ModuleName::from_name(&name.id),
                )]
            }
            _ => Vec::new(),
        }
    }

    fn as_item(x: &Expr) -> Option<Self> {
        match x {
            Expr::StringLiteral(x) => {
                Some(DunderAllEntry::Name(x.range, Name::new(x.value.to_str())))
            }
            _ => None,
        }
    }
}

struct DefinitionsBuilder<'a> {
    module_name: ModuleName,
    is_init: bool,
    config: &'a Config,
    inner: Definitions,
}

impl Definitions {
    pub fn new(x: &[Stmt], module_name: ModuleName, is_init: bool, config: &Config) -> Self {
        let mut builder = DefinitionsBuilder {
            module_name,
            config,
            is_init,
            inner: Definitions::default(),
        };
        builder.stmts(x);
        builder.inner
    }

    /// Add an implicit `from builtins import *` to the definitions.
    pub fn inject_builtins(&mut self) {
        self.import_all.entry(ModuleName::builtins()).or_default();
    }

    pub fn ensure_dunder_all(&mut self, style: ModuleStyle) {
        if self.definitions.contains_key(&dunder::ALL) {
            // Explicitly defined, so don't redefine it
            return;
        }
        if style == ModuleStyle::Executable {
            for (x, range) in self.import_all.iter() {
                self.dunder_all.push(DunderAllEntry::Module(*range, *x));
            }
        }
        for (name, (range, defn, _)) in self.definitions.iter() {
            if !name.starts_with('_')
                && (style == ModuleStyle::Executable
                    || matches!(defn, DefinitionStyle::Local | DefinitionStyle::ImportAsEq))
            {
                self.dunder_all
                    .push(DunderAllEntry::Name(*range, name.clone()));
            }
        }
    }
}

impl<'a> DefinitionsBuilder<'a> {
    fn stmts(&mut self, x: &[Stmt]) {
        for x in x {
            self.stmt(x);
        }
    }

    fn add_name(&mut self, x: &Name, range: TextRange, style: DefinitionStyle) {
        match self.inner.definitions.entry(x.clone()) {
            Entry::Occupied(mut e) => {
                e.get_mut().1 = cmp::min(e.get().1, style);
                e.get_mut().2 += 1;
            }
            Entry::Vacant(e) => {
                e.insert((range, style, 1));
            }
        }
    }

    fn add_identifier(&mut self, x: &Identifier, style: DefinitionStyle) {
        self.add_name(&x.id, x.range, style);
    }

    fn expr_lvalue(&mut self, x: &Expr) {
        let mut add_name = |x: &ExprName| self.add_name(&x.id, x.range, DefinitionStyle::Local);
        Ast::expr_lvalue(x, &mut add_name)
    }

    fn pattern(&mut self, x: &Pattern) {
        Ast::pattern_lvalue(x, &mut |x| self.add_identifier(x, DefinitionStyle::Local));
    }

    fn stmt(&mut self, x: &Stmt) {
        match x {
            Stmt::Import(x) => {
                for a in &x.names {
                    let module = ModuleName::from_name(&a.name.id);
                    match &a.asname {
                        None => self.add_name(
                            &module.first_component(),
                            a.name.range,
                            DefinitionStyle::ImportModule,
                        ),
                        Some(alias) => self.add_identifier(
                            alias,
                            if alias.id == a.name.id {
                                DefinitionStyle::ImportAsEq
                            } else {
                                DefinitionStyle::ImportAs
                            },
                        ),
                    };
                }
            }
            Stmt::ImportFrom(x) => {
                for a in &x.names {
                    if &a.name == "*" {
                        if let Some(module) = self.module_name.new_maybe_relative(
                            self.is_init,
                            x.level,
                            x.module.as_ref().map(|x| &x.id),
                        ) {
                            self.inner.import_all.insert(module, a.name.range);
                        }
                    } else {
                        let style = if a.asname.as_ref().map(|x| &x.id) == Some(&a.name.id) {
                            DefinitionStyle::ImportAsEq
                        } else if a.asname.is_some() {
                            DefinitionStyle::ImportAs
                        } else {
                            DefinitionStyle::Import
                        };
                        self.add_identifier(a.asname.as_ref().unwrap_or(&a.name), style);
                        if style == DefinitionStyle::ImportAsEq
                            && a.name.id == dunder::ALL
                            && let Some(module) = self.module_name.new_maybe_relative(
                                self.is_init,
                                x.level,
                                x.module.as_ref().map(|x| &x.id),
                            )
                        {
                            self.inner.dunder_all = vec![DunderAllEntry::Module(x.range, module)]
                        }
                    }
                }
            }
            Stmt::ClassDef(x) => {
                self.add_identifier(&x.name, DefinitionStyle::Local);
                return; // These things are inside a scope
            }
            Stmt::Assign(x) => {
                for t in &x.targets {
                    self.expr_lvalue(t);
                    if DunderAllEntry::is_all(t) {
                        self.inner.dunder_all = DunderAllEntry::as_list(&x.value);
                    }
                }
            }
            Stmt::AugAssign(x) => {
                if DunderAllEntry::is_all(&x.target) && x.op == Operator::Add {
                    self.inner
                        .dunder_all
                        .extend(DunderAllEntry::as_list(&x.value));
                } else {
                    self.expr_lvalue(&x.target);
                }
            }
            Stmt::Expr(StmtExpr {
                value:
                    box Expr::Call(
                        ExprCall {
                            func: box Expr::Attribute(ExprAttribute { value, attr, .. }),
                            arguments,
                            ..
                        },
                        ..,
                    ),
                ..
            }) if DunderAllEntry::is_all(value)
                && arguments.len() == 1
                && arguments.keywords.is_empty() =>
            {
                match attr.as_str() {
                    "extend" => self
                        .inner
                        .dunder_all
                        .extend(DunderAllEntry::as_list(&arguments.args[0])),
                    "append" => self
                        .inner
                        .dunder_all
                        .extend(DunderAllEntry::as_item(&arguments.args[0])),
                    "remove" => {
                        if let Some(DunderAllEntry::Name(range, remove)) =
                            DunderAllEntry::as_item(&arguments.args[0])
                        {
                            self.inner
                                .dunder_all
                                .push(DunderAllEntry::Remove(range, remove));
                        }
                    }
                    _ => {}
                }
            }
            Stmt::AnnAssign(x) => self.expr_lvalue(&x.target),
            Stmt::TypeAlias(x) => self.expr_lvalue(&x.name),
            Stmt::FunctionDef(x) => {
                self.add_identifier(&x.name, DefinitionStyle::Local);
                return; // don't recurse because a separate scope
            }
            Stmt::For(x) => self.expr_lvalue(&x.target),
            Stmt::With(x) => {
                for x in &x.items {
                    if let Some(target) = &x.optional_vars {
                        self.expr_lvalue(target);
                    }
                }
            }
            Stmt::Match(x) => {
                for x in &x.cases {
                    self.pattern(&x.pattern);
                }
            }
            Stmt::Try(x) => {
                for x in &x.handlers {
                    match x {
                        ExceptHandler::ExceptHandler(x) => {
                            if let Some(name) = &x.name {
                                self.add_identifier(name, DefinitionStyle::Local);
                            }
                        }
                    }
                }
            }
            Stmt::If(x) => {
                for (test, body) in Ast::if_branches(x) {
                    let b = self.config.evaluate_bool_opt(test);
                    if b != Some(false) {
                        self.stmts(body);
                    }
                    if b == Some(true) {
                        break;
                    }
                }
                return; // We went through the relevant branches already
            }
            _ => {}
        }
        Visitors::visit_stmt(x, |x| self.stmt(x))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::util::prelude::SliceExt;

    fn unrange(x: &mut DunderAllEntry) {
        match x {
            DunderAllEntry::Name(range, _)
            | DunderAllEntry::Module(range, _)
            | DunderAllEntry::Remove(range, _) => {
                *range = TextRange::default();
            }
        }
    }

    fn check(contents: &str, import_all: &[&str], defs: &[&str]) -> Definitions {
        let ast = Ast::parse(contents).0;
        let mut res = Definitions::new(
            &ast.body,
            ModuleName::from_str("main"),
            false,
            &Config::default(),
        );
        assert_eq!(
            import_all,
            res.import_all
                .keys()
                .map(|x| x.as_str())
                .collect::<Vec<_>>()
        );
        assert_eq!(
            defs,
            res.definitions
                .keys()
                .map(|x| x.as_str())
                .collect::<Vec<_>>(),
        );
        res.dunder_all.iter_mut().for_each(unrange);
        res
    }

    #[test]
    fn test_definitions() {
        check(
            r#"
from foo import *
from bar import baz as qux
from bar import moo
import mod.ule
import mod.lue

def x():
    y = 1

for z, w in []:
    pass

no.thing = 8

n = True

r[p] = 1
"#,
            &["foo"],
            &["qux", "moo", "mod", "x", "z", "w", "n"],
        );
    }

    #[test]
    fn test_all() {
        let defs = check(
            r#"
from foo import *
a = 1
b = 1

# Follow the spec at https://typing.readthedocs.io/en/latest/spec/distributing.html#library-interface-public-and-private-symbols
__all__ = ("a", "b")
__all__ += ["a", "b"]
__all__ += foo.__all__
__all__.extend(['a', 'b'])
__all__.extend(foo.__all__)
__all__.append('a')
__all__.remove('r')
        "#,
            &["foo"],
            &["a", "b", "__all__"],
        );
        let loc = TextRange::default();
        let a = &DunderAllEntry::Name(loc, Name::new("a"));
        let b = &DunderAllEntry::Name(loc, Name::new("b"));
        let foo = &DunderAllEntry::Module(loc, ModuleName::from_str("foo"));
        let r = &DunderAllEntry::Remove(loc, Name::new("r"));
        assert_eq!(
            defs.dunder_all.map(|x| x),
            vec![a, b, a, b, foo, a, b, foo, a, r]
        );
    }

    #[test]
    fn test_all_reexport() {
        // Not in the spec, but see collections.abc which does this.
        let defs = check(
            r#"
from _collections_abc import *
from _collections_abc import __all__ as __all__
"#,
            &["_collections_abc"],
            &["__all__"],
        );
        assert_eq!(
            defs.dunder_all,
            vec![DunderAllEntry::Module(
                TextRange::default(),
                ModuleName::from_str("_collections_abc")
            )]
        );
    }
}
