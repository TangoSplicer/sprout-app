// rust/sprout_compiler/src/runtime.rs
use std::collections::HashMap;

pub struct SproutRuntime {
    state: HashMap<String, Value>,
}

#[derive(Debug, Clone)]
pub enum Value {
    Number(f64),
    String(String),
    Boolean(bool),
    List(Vec<Value>),
}

impl SproutRuntime {
    pub fn new() -> Self {
        Self {
            state: HashMap::new(),
        }
    }

    pub fn set(&mut self, name: &str, value: Value) {
        self.state.insert(name.to_string(), value);
    }

    pub fn get(&self, name: &str) -> Option<&Value> {
        self.state.get(name)
    }

    pub fn run_action(&mut self, code: &str) {
        if code.contains("++") {
            // Simple counter logic
            if let Some(Value::Number(n)) = self.get("count") {
                self.set("count", Value::Number(n + 1.0));
            }
        }
    }
}