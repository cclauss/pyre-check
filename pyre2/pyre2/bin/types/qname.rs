/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

//! A qualified name - name plus its location.

use std::cmp::Ordering;
use std::fmt;

use ruff_python_ast::name::Name;
use ruff_python_ast::Identifier;
use ruff_text_size::TextRange;
use ruff_text_size::TextSize;

use crate::module::module_info::ModuleInfo;
use crate::module::module_name::ModuleName;

/// A name, plus where it is defined.
#[derive(Debug, Clone)]
pub struct QName {
    pub name: Identifier,
    pub module: ModuleInfo,
}

impl PartialEq for QName {
    fn eq(&self, other: &Self) -> bool {
        self.key() == other.key()
    }
}

impl Eq for QName {}

impl PartialOrd for QName {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

impl Ord for QName {
    fn cmp(&self, other: &Self) -> Ordering {
        self.key().cmp(&other.key())
    }
}

impl QName {
    fn key(&self) -> (&Name, TextSize, TextSize, ModuleName) {
        (
            &self.name.id,
            self.name.range.start(),
            self.name.range.end(),
            self.module.name(),
        )
    }

    pub fn new(name: Identifier, module: ModuleInfo) -> Self {
        Self { name, module }
    }

    pub fn id(&self) -> &Name {
        &self.name.id
    }

    pub fn range(&self) -> TextRange {
        self.name.range
    }

    pub fn fmt_name(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.name)
    }

    pub fn fmt_with_module(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}.{}", self.module.name(), self.name)
    }

    pub fn fmt_with_location(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "{}.{}@{}",
            self.module.name(),
            self.name.id,
            self.module.source_range(self.name.range)
        )
    }
}
