// rust/sprout_compiler/tests/parser_test.rs
#[cfg(test)]
mod tests {
    use sprout_compiler::parser::Parser;

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
        let result = Parser::new(source).parse();
        assert!(result.is_ok());
    }

    #[test]
    fn test_parse_sync_and_notify_actions() {
        let source = r#"
            app "Collaborative App" {
              start = Home
            }
            screen Home {
              ui {
                button "Sync Now" {
                  sync tasks
                  notify "Sync complete!"
                }
              }
            }
        "#;
        let result = Parser::new(source).parse();
        assert!(result.is_ok());
    }
}
