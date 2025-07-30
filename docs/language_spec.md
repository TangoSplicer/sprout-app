# SproutScript Language Specification

## App
```sprout
app "My App" {
  start = Home
}

screen Home {
  ui {
    label("Hello")
  }
}

state count = 0

button("++") {
  count = count + 1
}

button("Next") -> Detail