use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use thiserror::Error;
use std::time::{SystemTime, UNIX_EPOCH};

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
    pub code_quality_score: u8,
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
    let mut report = SecurityReport::default();
    
    // Size limits
    if source.len() > 1_000_000 {
        return Err(SproutError::Security("Source code exceeds size limit (1MB)".to_string()));
    }
    
    // Empty code check
    if source.trim().is_empty() {
        return Err(SproutError::Security("Source code cannot be empty".to_string()));
    }
    
    // Dangerous patterns based on security level
    let (dangerous_patterns, blocked_urls) = match security_level {
        SecurityLevel::Strict => (
            vec![
                ("import", "Import statements not allowed in strict mode"),
                ("require", "Require statements not allowed"),
                ("eval", "Code evaluation functions blocked"),
                ("exec", "Code execution functions blocked"),
                ("__import__", "Dynamic imports blocked"),
                ("getattr", "Attribute access functions blocked"),
                ("setattr", "Attribute modification functions blocked"),
                ("system", "System calls blocked"),
                ("shell", "Shell access blocked"),
                ("process", "Process manipulation blocked"),
                ("subprocess", "Subprocess creation blocked"),
                ("file(", "Direct file access blocked"),
                ("open(", "File opening functions blocked"),
            ],
            true
        ),
        SecurityLevel::Moderate => (
            vec![
                ("eval", "Code evaluation functions blocked"),
                ("exec", "Code execution functions blocked"),
                ("__import__", "Dynamic imports blocked"),
                ("system", "System calls blocked"),
                ("shell", "Shell access blocked"),
                ("subprocess", "Subprocess creation blocked"),
            ],
            false
        ),
        SecurityLevel::Permissive => (
            vec![
                ("eval", "Code evaluation detected"),
                ("exec", "Code execution detected"),
            ],
            false
        ),
    };
    
    // Check for dangerous patterns
    for (pattern, description) in dangerous_patterns {
        if source.to_lowercase().contains(pattern) {
            match security_level {
                SecurityLevel::Strict | SecurityLevel::Moderate => {
                    return Err(SproutError::Security(format!("Security violation: {}", description)));
                },
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
            return Err(SproutError::Security("External URLs not allowed in strict mode".to_string()));
        } else {
            report.security_warnings.push("External URL detected".to_string());
        }
    }
    
    // Calculate code quality score
    report.code_quality_score = calculate_code_quality_score(source);
    
    // Determine risk level
    report.risk_level = if !report.external_resources.is_empty() || report.security_warnings.len() > 3 {
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
    
    // Deduct points for various issues
    let lines: Vec<&str> = source.lines().collect();
    
    // Too many lines
    if lines.len() > 1000 {
        score = score.saturating_sub(20);
    }
    
    // Long lines
    let long_lines = lines.iter().filter(|line| line.len() > 120).count();
    score = score.saturating_sub((long_lines * 2) as u8);
    
    // Deeply nested structures
    let max_nesting = calculate_max_nesting(source);
    if max_nesting > 8 {
        score = score.saturating_sub((max_nesting - 8) as u8 * 5);
    }
    
    // Comments ratio (good)
    let comment_lines = lines.iter().filter(|line| line.trim_start().starts_with("//")).count();
    let comment_ratio = comment_lines as f32 / lines.len() as f32;
    if comment_ratio > 0.1 {
        score = std::cmp::min(100, score + 10);
    }
    
    score
}

fn calculate_max_nesting(source: &str) -> usize {
    let mut max_depth = 0;
    let mut current_depth = 0;
    
    for char in source.chars() {
        match char {
            '{' => {
                current_depth += 1;
                max_depth = std::cmp::max(max_depth, current_depth);
            },
            '}' => {
                if current_depth > 0 {
                    current_depth -= 1;
                }
            },
            _ => {}
        }
    }
    
    max_depth
}

fn calculate_checksum(data: &[u8]) -> String {
    use sha2::{Sha256, Digest};
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
        Ok(result) => serde_json::to_string(&result).unwrap_or_else(|_| "Serialization error".to_string()),
        Err(e) => format!("Error: {}", e),
    }
}

#[frb(sync)]
pub fn parse_source_safe(source: &str, security_level: &SecurityLevel) -> Result<ParseResult, SproutError> {
    // Validate input security
    let security_report = match validate_source_code(source, security_level) {
        Ok(report) => report,
        Err(e) => return Ok(ParseResult {
            success: false,
            ast: None,
            errors: vec![e.to_string()],
            warnings: vec![],
            security_report: None,
        }),
    };
    
    // Parse the AST
    match parser::parse(source) {
        Ok(ast) => {
            let ast_debug = format!("{:#?}", ast);
            Ok(ParseResult {
                success: true,
                ast: Some(ast_debug),
                errors: vec![],
                warnings: security_report.security_warnings.clone(),
                security_report: Some(security_report),
            })
        },
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
                vec![] // Return empty on error
            }
        },
        Err(_) => vec![],
    }
}

#[frb(sync)]
pub fn compile_with_security(
    source: &str, 
    options: &CompileOptions, 
    security_level: &SecurityLevel
) -> Result<CompileResult, SproutError> {
    let start_time = get_compilation_time();
    
    // Security validation
    let mut security_report = validate_source_code(source, security_level)?;
    
    // Parse first
    match parser::parse(source) {
        Ok(ast) => {
            // Enhanced security analysis on AST
            let analyzer = security::SecurityAnalyzer::default();
            match analyzer.analyze_app(&ast) {
                Ok(ast_report) => {
                    // Merge security reports
                    security_report.required_permissions.extend(ast_report.required_permissions);
                    security_report.external_resources.extend(ast_report.external_resources);
                    security_report.navigation_targets.extend(ast_report.navigation_targets);
                    security_report.function_calls.extend(ast_report.function_calls);
                    
                    // Update risk level based on AST analysis
                    if ast_report.get_risk_level() == security::RiskLevel::High {
                        security_report.risk_level = RiskLevel::High;
                    }
                },
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
            
            // Generate WASM
            let wasm_bytes = if options.optimize {
                generator::generate_optimized(&ast)
            } else {
                generator::generate(&ast)
            };
            
            let checksum = calculate_checksum(&wasm_bytes);
            let permissions = extract_permissions(&ast);
            let entry_points = extract_entry_points(&ast);
            
            Ok(CompileResult {
                success: true,
                wasm: wasm_bytes,
                errors: vec![],
                warnings: security_report.security_warnings.clone(),
                metadata: CompileMetadata {
                    size: wasm_bytes.len(),
                    checksum,
                    permissions,
                    entry_points,
                    compilation_time: get_compilation_time() - start_time,
                    compiler_version: env!("CARGO_PKG_VERSION").to_string(),
                    target_platform: options.target_platform.clone(),
                },
                security_report,
            })
        },
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
        analyze_ui_permissions(&screen.ui, &mut permissions);
    }
    
    permissions.into_iter().collect()
}

fn analyze_ui_permissions(ui: &ast::UI, permissions: &mut HashSet<String>) {
    match ui {
        ast::UI::Image { .. } => {
            permissions.insert("READ_EXTERNAL_STORAGE".to_string());
        },
        ast::UI::Button { action: Some(action), .. } => {
            if action.contains("camera") {
                permissions.insert("CAMERA".to_string());
            }
            if action.contains("location") {
                permissions.insert("ACCESS_FINE_LOCATION".to_string());
            }
            if action.contains("notification") {
                permissions.insert("POST_NOTIFICATIONS".to_string());
            }
        },
        ast::UI::Column(children) | ast::UI::Row(children) | ast::UI::Stack(children) => {
            for child in children {
                analyze_ui_permissions(child, permissions);
            }
        },
        ast::UI::List { child, .. } => {
            analyze_ui_permissions(child, permissions);
        },
        ast::UI::Conditional { then_branch, else_branch, .. } => {
            analyze_ui_permissions(then_branch, permissions);
            if let Some(else_branch) = else_branch {
                analyze_ui_permissions(else_branch, permissions);
            }
        },
        _ => {}
    }
}

fn extract_entry_points(ast: &ast::App) -> Vec<String> {
    let mut entry_points = vec![ast.start_screen.clone()];
    
    for screen in &ast.screens {
        if let Some(nav_targets) = find_navigation_targets(&screen.ui) {
            entry_points.extend(nav_targets);
        }
    }
    
    entry_points.sort();
    entry_points.dedup();
    entry_points
}

fn find_navigation_targets(ui: &ast::UI) -> Option<Vec<String>> {
    let mut targets = Vec::new();
    
    match ui {
        ast::UI::Button { navigate: Some(nav), .. } => {
            targets.push(nav.screen.clone());
        },
        ast::UI::Column(children) | ast::UI::Row(children) | ast::UI::Stack(children) => {
            for child in children {
                if let Some(child_targets) = find_navigation_targets(child) {
                    targets.extend(child_targets);
                }
            }
        },
        ast::UI::List { child, .. } => {
            if let Some(child_targets) = find_navigation_targets(child) {
                targets.extend(child_targets);
            }
        },
        ast::UI::Conditional { then_branch, else_branch, .. } => {
            if let Some(then_targets) = find_navigation_targets(then_branch) {
                targets.extend(then_targets);
            }
            if let Some(else_branch) = else_branch {
                if let Some(else_targets) = find_navigation_targets(else_branch) {
                    targets.extend(else_targets);
                }
            }
        },
        _ => {}
    }
    
    if targets.is_empty() {
        None
    } else {
        Some(targets)
    }
}

// Version and system info
#[frb(sync)]
pub fn get_compiler_info() -> String {
    serde_json::to_string(&serde_json::json!({
        "name": env!("CARGO_PKG_NAME"),
        "version": env!("CARGO_PKG_VERSION"),
        "description": env!("CARGO_PKG_DESCRIPTION"),
        "homepage": env!("CARGO_PKG_HOMEPAGE"),
        "repository": env!("CARGO_PKG_REPOSITORY"),
        "security_level": "strict",
        "build_info": {
            "target": env!("TARGET"),
            "profile": if cfg!(debug_assertions) { "debug" } else { "release" },
            "opt_level": env!("OPT_LEVEL"),
        },
        "features": [
            "syntax_highlighting",
            "real_time_compilation", 
            "security_validation",
            "permission_analysis",
            "wasm_generation",
            "ast_optimization",
            "code_quality_analysis"
        ]
    })).unwrap_or_else(|_| "{}".to_string())
}

// Performance benchmarking
#[frb(sync)]
pub fn benchmark_compilation(source: String, iterations: u32) -> String {
    let mut times = Vec::new();
    
    for _ in 0..iterations {
        let start = std::time::Instant::now();
        let _ = compile(source.clone());
        let duration = start.elapsed();
        times.push(duration.as_millis() as u64);
    }
    
    let avg_time = times.iter().sum::<u64>() / times.len() as u64;
    let min_time = *times.iter().min().unwrap_or(&0);
    let max_time = *times.iter().max().unwrap_or(&0);
    
    serde_json::to_string(&serde_json::json!({
        "iterations": iterations,
        "average_ms": avg_time,
        "min_ms": min_time,
        "max_ms": max_time,
        "source_size": source.len(),
        "times": times
    })).unwrap_or_else(|_| "{}".to_string())
}

pub mod ast;
pub mod parser;
pub mod generator;
pub mod runtime;
pub mod security;

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
        
        let result = compile_with_security(safe_code, &CompileOptions::default(), &SecurityLevel::Strict);
        assert!(result.is_ok());
        assert!(result.unwrap().success);
    }

    #[test]
    fn test_code_quality_scoring() {
        let good_code = "// This is a comment\napp \"Test\" {\n  start = \"Home\"\n}";
        let score = calculate_code_quality_score(good_code);
        assert!(score > 90);
    }
}
