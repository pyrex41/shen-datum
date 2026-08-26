/** Inert parser for Shen Datum Notation (SDN) 0.1. */

export type NumberValue = number | bigint;
export interface SymbolDatum { kind: 'symbol'; name: string }
export interface StringDatum { kind: 'string'; value: string }
export interface BooleanDatum { kind: 'boolean'; value: boolean }
export interface NumberDatum { kind: 'number'; value: NumberValue; raw?: string }
export interface ListDatum { kind: 'list'; items: Datum[]; tail?: Datum }
export interface VectorDatum { kind: 'vector'; items: Datum[] }
export interface TupleDatum { kind: 'tuple'; items: Datum[] }
export type Datum = SymbolDatum | StringDatum | BooleanDatum | NumberDatum | ListDatum | VectorDatum | TupleDatum;

export class ParseError extends Error {
  constructor(public category: string, message: string, public offset: number) {
    super(`${category} at offset ${offset}: ${message}`); this.name = 'SDNParseError';
  }
}

const isWS = (c: string) => c === ' ' || c === '\t' || c === '\n' || c === '\r';
const isHex = (c: string) => !!c && /^[0-9a-fA-F]$/.test(c);
const bareInitial = (c: string) => !!c && /^[A-Za-z=\-*+\/_?$!@~.&%'#`;:]$/.test(c);
const bareRest = (c: string) => bareInitial(c) || /^[0-9]$/.test(c);

class Parser {
  constructor(public text: string, public pos = 0) {}
  err(cat: string, msg: string): never { throw new ParseError(cat, msg, this.pos); }
  eof() { return this.pos >= this.text.length; }
  peek() { return this.text[this.pos] || ''; }
  spacing() {
    for (;;) {
      while (isWS(this.peek())) this.pos++;
      if (this.text.startsWith('\\\\', this.pos)) {
        this.pos += 2; while (!this.eof() && this.peek() !== '\n' && this.peek() !== '\r') this.pos++;
        if (this.peek() === '\r') { this.pos++; if (this.peek() === '\n') this.pos++; }
        else if (this.peek() === '\n') this.pos++;
        continue;
      }
      break;
    }
  }
  requireSep() { const p = this.pos; this.spacing(); if (this.pos === p) this.err('unexpected-token', 'expected separator'); }
  parseDocument(): Datum {
    this.spacing(); if (this.eof()) this.err('unexpected-eof', 'empty input');
    const d = this.datum(); this.spacing(); if (!this.eof()) this.err('trailing-data', 'multiple top-level data'); return d;
  }
  datum(): Datum {
    this.spacing(); const c = this.peek();
    if (!c) this.err('unexpected-eof', 'expected datum');
    if (c === '"') return { kind: 'string', value: this.string() };
    if (c === '[') return this.list(); if (c === '<') return this.vector(); if (c === '(') return this.tuple();
    if (this.text.startsWith('#s"', this.pos)) { this.pos += 2; return { kind: 'symbol', name: this.string() }; }
    return this.atom();
  }
  string(): string {
    if (this.peek() !== '"') this.err('unexpected-token', 'expected quote'); this.pos++; let out = '';
    while (!this.eof()) { const c = this.peek(); this.pos++;
      if (c === '"') return out;
      if (c < ' ' || c === '\\') { if (c !== '\\') this.err('invalid-escape', 'control character in string'); this.pos--; out += this.escape(); }
      else out += c;
    }
    this.err('unexpected-eof', 'unterminated string');
  }
  escape(): string {
    if (this.peek() !== '\\') this.err('invalid-escape', 'expected escape'); this.pos++; const c = this.peek(); this.pos++;
    const map: Record<string,string> = {'"':'"','\\':'\\','/':'/','b':'\b','f':'\f','n':'\n','r':'\r','t':'\t'};
    if (c in map) return map[c];
    if (c !== 'u') this.err('invalid-escape', 'unknown escape');
    if (this.peek() === '{') { this.pos++; let h=''; while (isHex(this.peek())) h += this.text[this.pos++]; if (!h || this.peek() !== '}') this.err('invalid-escape','invalid unicode escape'); this.pos++; const n=parseInt(h,16); if (n>0x10ffff || (n>=0xd800&&n<=0xdfff)) this.err('invalid-escape','invalid scalar'); return String.fromCodePoint(n); }
    let h=''; for(let i=0;i<4;i++){ if(!isHex(this.peek())) this.err('invalid-escape','invalid unicode escape'); h+=this.text[this.pos++]; }
    const n=parseInt(h,16); if(n>=0xd800&&n<=0xdbff){ if(this.text.substr(this.pos,2)!=='\\u') this.err('invalid-escape','unpaired surrogate'); this.pos+=2; let h2=''; for(let i=0;i<4;i++){if(!isHex(this.peek())) this.err('invalid-escape','invalid surrogate'); h2+=this.text[this.pos++];} const n2=parseInt(h2,16); if(n2<0xdc00||n2>0xdfff)this.err('invalid-escape','invalid surrogate pair'); return String.fromCodePoint(0x10000+(n-0xd800)*0x400+n2-0xdc00); } if(n>=0xdc00) this.err('invalid-escape','unpaired surrogate'); return String.fromCharCode(n);
  }
  atom(): Datum {
    const start=this.pos; while(this.pos<this.text.length && !isWS(this.peek()) && !'[]()<>|'.includes(this.peek()) && !this.text.startsWith('\\\\',this.pos)) this.pos++;
    if(this.pos===start) this.err('unexpected-token','invalid character'); const tok=this.text.slice(start,this.pos);
    if(tok==='true'||tok==='false') return {kind:'boolean',value:tok==='true'};
    if(/^[+-]?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$/.test(tok)) { const n=Number(tok); if(!Number.isFinite(n)) this.err('invalid-number','number out of range'); if(!tok.includes('.')&&!/[eE]/.test(tok) && !Number.isSafeInteger(n)) return {kind:'number',value:BigInt(tok),raw:tok}; return {kind:'number',value:n,raw:tok}; }
    if(/^[+-]?[0-9]/.test(tok)) this.err('invalid-number','invalid number syntax');
    if(!bareInitial(tok[0]) || [...tok].some(c=>!bareRest(c))) this.err('invalid-symbol','invalid symbol');
    return {kind:'symbol',name:tok};
  }
  list(): Datum { this.pos++; this.spacing(); const items:Datum[]=[]; let tail:Datum|undefined;
    if(this.peek()===']'){this.pos++; return {kind:'list',items};}
    for(;;){ if(this.peek()==='|'||this.peek()===']') this.err('invalid-list-tail','list requires head'); items.push(this.datum()); const before=this.pos; this.spacing(); if(this.peek()===']'){this.pos++; return {kind:'list',items};} if(this.peek()==='|'){if(tail) this.err('invalid-list-tail','multiple pipes'); this.pos++; this.requireSep(); tail=this.datum(); this.spacing(); if(this.peek()!==']') this.err('invalid-list-tail','pipe must be final'); this.pos++; if(tail.kind==='list'&&!tail.tail){ return {kind:'list',items:items.concat(tail.items)}; } return {kind:'list',items,tail}; } if(this.pos===before && !'[(<"#'.includes(this.peek())) this.err('unexpected-token','expected separator'); }
  }
  vector(): Datum { this.pos++; const items:Datum[]=[]; this.spacing(); while(this.peek()!=='>'){ if(this.eof()) this.err('unexpected-eof','unterminated vector'); items.push(this.datum()); const p=this.pos; this.spacing(); if(this.peek()==='>') break; if(this.pos===p && !'[(<"#'.includes(this.peek()))this.err('unexpected-token','expected separator'); } this.pos++; return {kind:'vector',items}; }
  tuple(): Datum { this.pos++; this.spacing(); const at=this.atom(); if(at.kind!=='symbol'||at.name!=='@p') this.err('invalid-tuple','parenthesized form must start @p'); this.requireSep(); const items=[this.datum()]; this.requireSep(); items.push(this.datum()); for(;;){const p=this.pos; this.spacing(); if(this.peek()===')'){this.pos++; return {kind:'tuple',items};} if(this.pos===p)this.err('unexpected-token','expected separator'); items.push(this.datum());} }
}

export function parse(input: string | Uint8Array): Datum { if(input instanceof Uint8Array){ try { input = new TextDecoder('utf-8',{fatal:true}).decode(input); } catch { throw new ParseError('invalid-utf8','invalid UTF-8',0); } } return new Parser(input).parseDocument(); }
export const parseDatum = parse;
export const decode = parse;
