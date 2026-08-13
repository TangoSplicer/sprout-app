#![allow(unexpected_cfgs)] // flutter_rust_bridge emits the checked `frb_expand` cfg.

use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::time::{SystemTime, UNIX_EPOCH};
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

#[derive(Deserialize, Serialize, Debug, Clone)]
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

impl Default for CompileOptions {
    fn default() -> Self {
        Self {
            enable_debugging: false,
            optimize: true,
            target_platform: default_target_platform(),
            include_metadata: false,
        }
    }
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
    pub code_quality_score: u8,
}

#[derive(Serialize, Debug, PartialEq, Default, Clone)]
pub enum RiskLevel {
    #[default]
    Low,
    Medium,
    High,
    Critical,
}

// Security validation with comprehensive checks
fn validate_source_code(
    source: &str,
    security_level: &SecurityLevel,
) -> Result<SecurityReport, SproutError> {
    let mut report = SecurityReport::default();

    // Size limits
    if source.len() > 1_000_000 {
        return Err(SproutError::Security(
            "Source code exceeds size limit (1MB)".to_string(),
        ));
    }

    // Empty code check
    if source.trim().is_empty() {
        return Err(SproutError::Security(
            "Source code cannot be empty".to_string(),
        ));
    }

    // Dangerous patterns based on security level
    let (dangerous_patterns, blocked_urls) = match security_level {
        SecurityLevel::Strict => (
            vec![
                ("eval", "Code evaluation functions blocked"),
                ("exec", "Code execution functions blocked"),
                ("system", "System calls blocked"),
                ("shell", "Shell access blocked"),
            ],
            true,
        ),
        SecurityLevel::Moderate => (
            vec![
                ("eval", "Code evaluation functions blocked"),
                ("exec", "Code execution functions blocked"),
            ],
            false,
        ),
        SecurityLevel::Permissive => (vec![("eval", "Code evaluation detected")], false),
    };

    // Check for dangerous patterns
    for (pattern, description) in dangerous_patterns {
        if source.to_lowercase().contains(pattern) {
            match security_level {
                SecurityLevel::Strict | SecurityLevel::Moderate => {
                    return Err(SproutError::Security(format!(
                        "Security violation: {}",
                        description
                    )));
                }
                SecurityLevel::Permissive => {
                    report.security_warnings.push(description.to_string());
                }
            }
        }
    }

    // Check for suspicious URL patterns
    let url_regex = regex::Regex::new(r"https?://[^\s]+").unwrap();
    if let Some(matches) = url_regex.find(source) {
        let url = matches.as_str();
        report.external_resources.insert(url.to_string());

        if blocked_urls {
            return Err(SproutError::Security(
                "External URLs not allowed in strict mode".to_string(),
            ));
        } else {
            report
                .security_warnings
                .push("External URL detected".to_string());
        }
    }

    // Calculate code quality score
    report.code_quality_score = calculate_code_quality_score(source);

    // Determine risk level
    report.risk_level =
        if !report.external_resources.is_empty() || report.security_warnings.len() > 3 {
            RiskLevel::High
        } else if !report.security_warnings.is_empty() {
            RiskLevel::Medium
        } else {
            RiskLevel::Low
        };

    Ok(report)
}

fn calculate_code_quality_score(source: &str) -> u8 {
    let mut score = 100u8;
    let lines: Vec<&str> = source.lines().collect();

    if lines.len() > 1000 {
        score = score.saturating_sub(20);
    }

    let long_lines = lines.iter().filter(|line| line.len() > 120).count();
    score = score.saturating_sub((long_lines * 2) as u8);

    score
}

fn calculate_checksum(data: &[u8]) -> String {
    use sha2::{Digest, Sha256};
    let mut hasher = Sha256::new();
    hasher.update(data);
    format!("{:x}", hasher.finalize())
}

fn get_compilation_time() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u64
}

// Main API functions
#[frb(sync)]
pub fn parse_dump(source: String) -> String {
    match parse_source_safe(&source, &SecurityLevel::Strict) {
        Ok(result) => {
            serde_json::to_string(&result).unwrap_or_else(|_| "Serialization error".to_string())
        }
        Err(e) => format!("Error: {}", e),
    }
}

#[frb(sync)]
pub fn parse_source_safe(
    source: &str,
    security_level: &SecurityLevel,
) -> Result<ParseResult, SproutError> {
    let security_report = match validate_source_code(source, security_level) {
        Ok(report) => report,
        Err(e) => {
            return Ok(ParseResult {
                success: false,
                ast: None,
                errors: vec![e.to_string()],
                warnings: vec![],
                security_report: None,
            })
        }
    };

    match parser::parse_sproutscript(source) {
        Ok(ast) => {
            let ast_debug = format!("{:#?}", ast);
            Ok(ParseResult {
                success: true,
                ast: Some(ast_debug),
                errors: vec![],
                warnings: security_report.security_warnings.clone(),
                security_report: Some(security_report),
            })
        }
        Err(e) => Ok(ParseResult {
            success: false,
            ast: None,
            errors: vec![format!("Parse error: {}", e)],
            warnings: vec![],
            security_report: Some(security_report),
        }),
    }
}

#[frb(sync)]
pub fn compile(source: String) -> Vec<u8> {
    match compile_with_security(&source, &CompileOptions::default(), &SecurityLevel::Strict) {
        Ok(result) => {
            if result.success {
                result.wasm
            } else {
                vec![]
            }
        }
        Err(_) => vec![],
    }
}

#[frb(sync)]
pub fn compile_with_security(
    source: &str,
    options: &CompileOptions,
    security_level: &SecurityLevel,
) -> Result<CompileResult, SproutError> {
    let start_time = get_compilation_time();
    let mut security_report = validate_source_code(source, security_level)?;

    match parser::parse_sproutscript(source) {
        Ok(ast) => {
            let analyzer = security::SecurityAnalyzer::default();
            match analyzer.analyze_app(&ast) {
                Ok(ast_report) => {
                    security_report
                        .required_permissions
                        .extend(ast_report.required_permissions);
                    security_report
                        .external_resources
                        .extend(ast_report.external_resources);
                    security_report
                        .navigation_targets
                        .extend(ast_report.navigation_targets);
                    security_report
                        .function_calls
                        .extend(ast_report.function_calls);

                    if ast_report.risk_level == security::RiskLevel::High {
                        security_report.risk_level = RiskLevel::High;
                    }
                }
                Err(e) => {
                    return Ok(CompileResult {
                        success: false,
                        wasm: vec![],
                        errors: vec![format!("Security analysis failed: {}", e)],
                        warnings: vec![],
                        metadata: CompileMetadata {
                            size: 0,
                            checksum: String::new(),
                            permissions: vec![],
                            entry_points: vec![],
                            compilation_time: get_compilation_time() - start_time,
                            compiler_version: env!("CARGO_PKG_VERSION").to_string(),
                            target_platform: options.target_platform.clone(),
                        },
                        security_report,
                    });
                }
            }

            let gen_options = generator::GeneratorOptions {
                target: match options.target_platform.as_str() {
                    "android" => generator::TargetPlatform::Android,
                    "ios" => generator::TargetPlatform::Ios,
                    _ => generator::TargetPlatform::Wasm,
                },
                optimize: options.optimize,
                include_debug_info: options.enable_debugging,
            };

            match generator::generate_code(&ast, gen_options) {
                Ok(code) => {
                    let wasm_bytes = code.into_bytes();
                    let wasm_len = wasm_bytes.len();
                    let checksum = calculate_checksum(&wasm_bytes);
                    let permissions = extract_permissions(&ast);
                    let entry_points = extract_entry_points(&ast);

                    Ok(CompileResult {
                        success: true,
                        wasm: wasm_bytes,
                        errors: vec![],
                        warnings: security_report.security_warnings.clone(),
                        metadata: CompileMetadata {
                            size: wasm_len,
                            checksum,
                            permissions,
                            entry_points,
                            compilation_time: get_compilation_time() - start_time,
                            compiler_version: env!("CARGO_PKG_VERSION").to_string(),
                            target_platform: options.target_platform.clone(),
                        },
                        security_report,
                    })
                }
                Err(e) => Ok(CompileResult {
                    success: false,
                    wasm: vec![],
                    errors: vec![format!("Generation error: {}", e)],
                    warnings: vec![],
                    metadata: CompileMetadata {
                        size: 0,
                        checksum: String::new(),
                        permissions: vec![],
                        entry_points: vec![],
                        compilation_time: get_compilation_time() - start_time,
                        compiler_version: env!("CARGO_PKG_VERSION").to_string(),
                        target_platform: options.target_platform.clone(),
                    },
                    security_report,
                }),
            }
        }
        Err(e) => Ok(CompileResult {
            success: false,
            wasm: vec![],
            errors: vec![format!("Parse error: {}", e)],
            warnings: vec![],
            metadata: CompileMetadata {
                size: 0,
                checksum: String::new(),
                permissions: vec![],
                entry_points: vec![],
                compilation_time: get_compilation_time() - start_time,
                compiler_version: env!("CARGO_PKG_VERSION").to_string(),
                target_platform: options.target_platform.clone(),
            },
            security_report,
        }),
    }
}

fn extract_permissions(ast: &ast::App) -> Vec<String> {
    let mut permissions = HashSet::new();
    for screen in &ast.screens {
        for ui in &screen.ui {
            analyze_ui_permissions(ui, &mut permissions);
        }
    }
    permissions.into_iter().collect()
}

fn analyze_ui_permissions(ui: &ast::UiElement, permissions: &mut HashSet<String>) {
    match ui {
        ast::UiElement::Image { source } => {
            if source.starts_with("http") {
                permissions.insert("INTERNET".to_string());
            }
            permissions.insert("READ_EXTERNAL_STORAGE".to_string());
        }
        ast::UiElement::Button { action, .. } => {
            analyze_action_permissions(action, permissions);
        }
        _ => {}
    }
}

fn analyze_action_permissions(action: &ast::Action, permissions: &mut HashSet<String>) {
    match action {
        ast::Action::CallFunction { function, .. } => {
            if function.contains("camera") {
                permissions.insert("CAMERA".to_string());
            }
            if function.contains("location") {
                permissions.insert("ACCESS_FINE_LOCATION".to_string());
            }
        }
        ast::Action::If { then, r#else, .. } => {
            analyze_action_permissions(then, permissions);
            if let Some(else_act) = r#else {
                analyze_action_permissions(else_act, permissions);
            }
        }
        ast::Action::Loop { body, .. } => {
            for act in body {
                analyze_action_permissions(act, permissions);
            }
        }
        _ => {}
    }
}

fn extract_entry_points(ast: &ast::App) -> Vec<String> {
    vec![ast.start_screen.clone()]
}

pub mod ast;
pub mod generator;
pub mod parser;
pub mod runtime;
pub mod security;

// C-compatible entry points used by the mobile bridge. Returned strings are
// heap-allocated and must be released through `sprout_string_free`.
use std::ffi::{CStr, CString};
use std::os::raw::c_char;

fn c_string(value: String) -> *mut c_char {
    CString::new(value)
        .unwrap_or_else(|_| CString::new("invalid UTF-8 output").expect("static string is valid"))
        .into_raw()
}

unsafe fn source_from_c(value: *const c_char) -> Result<String, SproutError> {
    if value.is_null() {
        return Err(SproutError::Compile("source must not be null".to_string()));
    }

    CStr::from_ptr(value)
        .to_str()
        .map(str::to_owned)
        .map_err(|_| SproutError::Compile("source must be valid UTF-8".to_string()))
}

/// Compiles SproutScript source and returns an owned, NUL-terminated result string.
///
/// # Safety
/// `source` must point to a non-null, NUL-terminated UTF-8 C string that remains
/// valid for this call. The returned pointer must be released exactly once with
/// [`sprout_string_free`].
#[no_mangle]
pub unsafe extern "C" fn compile_sprout_script(source: *const c_char) -> *mut c_char {
    match source_from_c(source) {
        Ok(source) => {
            match compile_with_security(&source, &CompileOptions::default(), &SecurityLevel::Strict)
            {
                Ok(result) if result.success => {
                    c_string(String::from_utf8_lossy(&result.wasm).into_owned())
                }
                Ok(result) => c_string(result.errors.join("; ")),
                Err(error) => c_string(error.to_string()),
            }
        }
        Err(error) => c_string(error.to_string()),
    }
}

/// Parses SproutScript source and returns an owned, NUL-terminated diagnostic string.
///
/// # Safety
/// `source` must point to a non-null, NUL-terminated UTF-8 C string that remains
/// valid for this call. The returned pointer must be released exactly once with
/// [`sprout_string_free`].
#[no_mangle]
pub unsafe extern "C" fn parse_sprout_script(source: *const c_char) -> *mut c_char {
    match source_from_c(source) {
        Ok(source) => c_string(parse_dump(source)),
        Err(error) => c_string(error.to_string()),
    }
}

/// Validates SproutScript source and returns `1` for valid input and `0` otherwise.
///
/// # Safety
/// `source` must point to a non-null, NUL-terminated UTF-8 C string that remains
/// valid for this call.
#[no_mangle]
pub unsafe extern "C" fn validate_code(source: *const c_char) -> i8 {
    match source_from_c(source) {
        Ok(source) => i8::from(validate_source_code(&source, &SecurityLevel::Strict).is_ok()),
        Err(_) => 0,
    }
}

#[no_mangle]
pub extern "C" fn get_last_error() -> *mut c_char {
    c_string(String::new())
}

#[no_mangle]
pub extern "C" fn get_version() -> *mut c_char {
    c_string(env!("CARGO_PKG_VERSION").to_string())
}

/// Releases a string returned by this library's C ABI functions.
///
/// # Safety
/// `value` must be either null or a pointer returned by this library's string-
/// returning C ABI functions. It must not have been freed previously and must not
/// be used after this call.
#[no_mangle]
pub unsafe extern "C" fn sprout_string_free(value: *mut c_char) {
    if !value.is_null() {
        drop(CString::from_raw(value));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_security_validation() {
        let dangerous_code = "eval('malicious code')";
        let result = validate_source_code(dangerous_code, &SecurityLevel::Strict);
        assert!(result.is_err());
    }

    #[test]
    fn test_safe_code_compilation() {
        let safe_code = r#"
            app "Test" {
                start = "Home"
            }

            screen Home {
                ui {
                    label "Hello World"
                }
            }
        "#;

        let result = compile_with_security(
            safe_code,
            &CompileOptions::default(),
            &SecurityLevel::Strict,
        );
        assert!(result.is_ok());
    }
}
