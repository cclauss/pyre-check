"use strict";(self.webpackChunk=self.webpackChunk||[]).push([[333],{40722:(e,t,n)=>{n.r(t),n.d(t,{default:()=>f});var r=n(67294),a=n(87190),l=n(94184),o=n.n(l),u=(n(39960),n(10412)),i=n(29656),c=n(99578),s=n(86341);u.default.canUseDOM&&n(5321);function d(e){return r.createElement("div",{style:{border:"1px solid lightgrey"}},r.createElement(i.fk,{value:e.code,options:{mode:"python",lineNumbers:!0,readOnly:!!e.busy&&"nocursor",indentUnit:4,indentWithTabs:!1},editorDidMount:function(t,n){e.setEditor(t),t.setOption("extraKeys",{Tab:function(e){var t=Array(e.getOption("indentUnit")+1).join(" ");e.replaceSelection(t)}})},onBeforeChange:function(t,n,r){e.setCode(r)}}))}function m(e){var t=e.busy?{color:"lightgrey",cursor:"default"}:null;return r.createElement("div",{style:{textAlign:"right"}},r.createElement("div",{className:o()("button button--outline button--secondary",c.Z.getStarted),style:t,onClick:e.check},e.busy?r.createElement("div",{className:c.Z.spinner}):null,"Check (Ctrl-Enter)"))}function p(e){var t=e.busy?{color:"lightgrey",cursor:"default"}:null;return r.createElement("div",{style:{textAlign:"right"}},r.createElement("div",{className:o()("button button--outline button--secondary",c.Z.getStarted),style:t,onClick:function(){navigator.clipboard.writeText(window.location.href)}},"Copy Url"))}function y(e){var t=e.results;if(null==t)return null;var n=t.data.errors;if(0!==n.length){var a=n.map((function(e){var t=e.line+":"+e.column+": "+e.description;return r.createElement("div",{key:t}," ",r.createElement("pre",null," ",t," ")," ")}));return r.createElement("div",null,a)}return r.createElement("div",null,"No Errors!")}function h(){var e=u.default.canUseDOM?new URLSearchParams(window.location.search).get("input"):null;return null==e?"# Pyre is being run in gradual typing mode: https://pyre-check.org/docs/types-in-python/#gradual-typing\n# Use the `# pyre-strict` header to run in strict mode, which requires annotations.\n\nfrom typing import *\n\n# reveal_type will produce a type error that tells you the type Pyre has\n# computed for the argument (in this case, int)\nreveal_type(1)\n":e}const f=function(){var e=(0,r.useState)(null),t=e[0],n=e[1],l=(0,r.useState)(!1),o=(l[0],l[1],(0,r.useState)(h())),u=o[0],i=o[1],f=(0,r.useState)(!1),g=f[0],E=f[1],b=(0,r.useState)(null),v=b[0],k=b[1],w=function(){E(!0);var e=function(e){var t=encodeURIComponent(e);return window.history.pushState(e,"unused","/play?input="+t),t}(u);fetch("https://play.pyre-check.org/check?input="+e,{method:"GET",mode:"cors",headers:{"Content-Type":"application/json"}}).then((function(e){return e.json()})).then((function(e){n(e),E(!1),function(e,t){e.getAllMarks().map((function(e){return e.clear()})),null!=t&&t.data.errors.map((function(t){return e.markText({line:t.line-1,ch:t.column},{line:t.stop_line-1,ch:t.stop_column},{className:"pyre-type-error"})}))}(v,e)})).catch((function(e){return console.error(e)}))},_=function(e){"Enter"===e.key&&(e.ctrlKey||e.metaKey)&&(e.preventDefault(),e.stopPropagation(),w())};return(0,r.useEffect)((function(){return window.addEventListener("keydown",_),function(){window.removeEventListener("keydown",_)}}),[u]),r.createElement(a.Z,{title:"Playground"},r.createElement("main",{className:c.Z.main},r.createElement(s.OssOnly,null,r.createElement("h1",{className:c.Z.heading},"Playground"),r.createElement(d,{code:u,results:t,setCode:i,setEditor:k,busy:g}),r.createElement("br",null),r.createElement("div",{className:c.Z.buttons+" check"},r.createElement(m,{check:w,busy:g}),r.createElement(p,{busy:g})),r.createElement("br",null),r.createElement("br",null),r.createElement(y,{results:t})),r.createElement(s.FbInternalOnly,null,r.createElement("h1",null," ","The Playground is not available in the internal static docs."," "),r.createElement("p",null,"You can use either",r.createElement("ul",null,r.createElement("li",null," ",r.createElement("a",{href:"https://pyre-check.org/play"},"the external playground")," ","or"),r.createElement("li",null," ",r.createElement("a",{href:"https://www.internalfb.com/intern/pyre/sandbox/"}," ","the internal sandbox"," "))),"to try Pyre in the browser."))))}},99578:(e,t,n)=>{n.d(t,{Z:()=>r});const r={heroBanner:"heroBanner_UJJx",buttons:"buttons_pzbO",features:"features_keug",media:"media_L2aT",featureImage:"featureImage_yA8i",main:"main_MeqP",playgroundMain:"playgroundMain_uARe",heading:"heading_AAq7",spinner:"spinner_Wr6O",spin:"spin_NH6Z",card:"card_UXd2",getStarted:"getStarted_Sjon",runPysa:"runPysa_zh3R",resultsCard:"resultsCard_BSEt"}}}]);