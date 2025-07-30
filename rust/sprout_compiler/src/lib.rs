// rust/sprout_compiler/src/lib.rs
use flutter_rust_bridge::frb;
use serde::Deserialize;

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CompileRequest {
    pub source: String,
}

#[frb(sync)]
pub fn parse_dump(source: String) -> String {
    match parser::parse(&source) {
        Ok(ast) => format!("{:?}", ast),
        Err(e) => format!("ParseError: {}", e),
    }
}

#[frb(sync)]
pub fn compile(source: String) -> Vec<u8> {
    match parser::parse(&source) {
        Ok(ast) => generator::generate(&ast),
        Err(_) => vec![], // Return empty WASM on error
    }
}

pub mod ast;
pub mod parser;
pub mod generator;
pub mod runtime;