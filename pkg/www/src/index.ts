// Features:
// - Mithril.js SPA with header and main content, mounted to document.body
import m from 'mithril'

const Header: m.Component = {
    view: () => m('nav', [
        m('p', 'Freyground'), m('p', "GitHub")
    ]),
}

const App: m.Component = {
    view: () => m('nav', [
        Header,
        m('main', m('p', 'Welcome.')),
    ]),
}

m.mount(document.body, App)
