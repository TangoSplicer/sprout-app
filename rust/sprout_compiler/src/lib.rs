use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum SproutError {
    #[error("Parse error: {0}")]
    Parse(String),
    #[error("Compile error: {0}")]
    Compile(String),
    #[error("Security violation: {0}")]
    Security(String),
    #[error("Runtime error: {0}")]
    Runtime(String),
    #[error("IO error: {0}")]
    Io(String),
}

#[derive(Deserialize, Serialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct CompileRequest {
    pub source: String,
    #[serde(default)]
    pub security_level: SecurityLevel,
    #[serde(default)]
    pub options: CompileOptions,
    #[serde(default)]
    pub project_name: Option<String>,
}

#[derive(Deserialize, Serialize, Debug, Clone, PartialEq, Default)]
#[serde(rename_all = "camelCase")]
pub enum SecurityLevel {
    #[default]
    Strict,
    Moderate,
    Permissive,
}

#[derive(Deserialize, Serialize, Debug, Clone, Default)]
#[serde(rename_all = "camelCase")]
pub struct CompileOptions {
    #[serde(default)]
    pub enable_debugging: bool,
    #[serde(default)]
    pub optimize: bool,
    #[serde(default = "default_target_platform")]
    pub target_platform: String,
    #[serde(default)]
    pub include_metadata: bool,
}

fn default_target_platform() -> String {
    "android".to_string()
}

#[derive(Serialize, Debug)]
pub struct ParseResult {
    pub success: bool,
    pub ast: Option<String>,
    pub errors: Vec<String>,
    pub warnings: Vec<String>,
    pub security_report: Option<SecurityReport>,
}

#[derive(Serialize, Debug)]
pub struct CompileResult {
    pub success: bool,
    pub wasm: Vec<u8>,
    pub errors: Vec<String>,
    pub warnings: Vec<String>,
    pub metadata: CompileMetadata,
    pub security_report: SecurityReport,
}

#[derive(Serialize, Debug)]
pub struct CompileMetadata {
    pub size: usize,
    pub checksum: String,
    pub permissions: Vec<String>,
    pub entry_points: Vec<String>,
    pub compilation_time: u64,
    pub compiler_version: String,
    pub target_platform: String,
}

#[derive(Serialize, Debug, Default)]
pub struct SecurityReport {
    pub risk_level: RiskLevel,
    pub required_permissions: HashSet<String>,
    pub external_resources: HashSet<String>,
    pub navigation_targets: HashSet<String>,
    pub function_calls: HashSet<String>,
    pub security_warnings: Vec<String>,
    pub code_quality_score: u8, // 0-100
}

#[derive(Serialize, Debug, PartialEq, Default)]
pub enum RiskLevel {
    #[default]
    Low,
    Medium, 
    High,
    Critical,
}

// Security validation with comprehensive checks
fn validate_source_code(source: &str, security_level: &SecurityLevel) -> Result<SecurityReport, SproutError> {
    let mut report
        
