import { Component, h } from 'preact';
import { Xterm, XtermOptions } from './xterm';

import '@xterm/xterm/css/xterm.css';

interface Props extends XtermOptions {
    id: string;
}

export class Terminal extends Component<Props> {
    private container: HTMLElement;
    private xterm: Xterm;

    constructor(props: Props) {
        super();
        this.xterm = new Xterm(props);
    }

    async componentDidMount() {
        const { xterm, container } = this;
        (document.fonts as FontFaceSet & { add(font: FontFace): void }).add(
            (await Promise.all([new FontFace('_', 'url(_.woff2)').load(), xterm.refreshToken()]))[0]
        );
        xterm.open(container);
        xterm.connect();
    }

    componentWillUnmount() {
        this.xterm.dispose();
    }

    render({ id }: Props) {
        return <div id={id} ref={c => (this.container = c as HTMLElement)}></div>;
    }
}
