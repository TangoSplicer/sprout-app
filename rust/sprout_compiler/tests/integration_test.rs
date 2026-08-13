use sprout_compiler::{
    compile, compile_with_security, parse_dump, parse_source_safe, CompileOptions, SecurityLevel,
};

const SAFE_SOURCE: &str = r#"
    app "TodoApp"
    screen Home {
        state count: 1
        ui {
            label "Count: ${count}"
            button "Continue"
        }
    }
"#;

#[test]
fn compiles_safe_source_with_strict_security() {
    let result = compile_with_security(
        SAFE_SOURCE,
        &CompileOptions::default(),
        &SecurityLevel::Strict,
    )
    .expect("compilation operation should complete");

    assert!(result.success, "errors: {:?}", result.errors);
    assert!(!result.wasm.is_empty());
    assert!(result.metadata.size > 0);
    assert!(!result.metadata.checksum.is_empty());
    assert_eq!(result.metadata.target_platform, "android");
}

#[test]
fn returns_an_empty_convenience_result_for_invalid_source() {
    let invalid_source = "screen MissingApplication {}";

    assert!(compile(invalid_source.to_string()).is_empty());
}

#[test]
fn reports_dangerous_source_without_building_an_artifact() {
    let malicious_source = r#"
        app "Unsafe"
        screen Home {
            state payload: "eval('untrusted input')"
        }
    "#;

    let result = parse_source_safe(malicious_source, &SecurityLevel::Strict)
        .expect("parse operation should return a structured result");

    assert!(!result.success);
    assert!(result.errors.iter().any(|error| error.contains("eval")));
    assert!(result.ast.is_none());
}

#[test]
fn parse_dump_is_machine_readable_for_valid_source() {
    let dump = parse_dump(SAFE_SOURCE.to_string());
    let result: serde_json::Value = serde_json::from_str(&dump).expect("valid JSON parse result");

    assert_eq!(result["success"], true);
    assert!(result["ast"].as_str().is_some());
    assert!(result["errors"].as_array().is_some_and(Vec::is_empty));
}
