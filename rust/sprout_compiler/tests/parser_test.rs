// rust/sprout_compiler/tests/parser_test.rs
#[cfg(test)]
mod tests {
    use super::parser::parse;

    #[test]
    fn test_parse_app() {
        let source = r#"
            app "Test" {
              start = Home
            }
            screen Home {
              ui { label("Hi") }
            }
        "#;
        let result = parse(source);
        assert!(result.is_ok());
    }
}