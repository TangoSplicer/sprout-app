# SproutScript Language Specification

SproutScript is a domain-specific language designed for creating mobile applications declaratively. It prioritizes readability, simplicity, and rapid development while maintaining the power needed for real-world applications.

## 1. Lexical Structure

### Identifiers
Identifiers start with a letter or underscore, followed by letters, digits, or underscores.
```sprout
screen_name, counter, my_variable
```

### Literals
- **Strings**: Enclosed in double quotes with interpolation support: `"Count: ${count}"`
- **Numbers**: Integers and decimals: `42`, `3.14`
- **Booleans**: `true`, `false`

### Keywords
`app`, `screen`, `state`, `ui`, `data`, `import`, `if`, `else`, `for`, `in`

---

## 2. App Structure

Every SproutScript application begins with an `app` declaration, specifying the entry screen and optional theme.

```sprout
app "Budget Planner" {
    start = Dashboard
    theme = "Forest"
}
```

---

## 3. Data Models

Data models define structured schemas for application state, enabling robust validation and record-based storage.

```sprout
data Transaction {
    label: String
    amount: Float
    category: String
    date: Date
}
```

---

## 4. Screens & UI Components

Screens encapsulate state and UI declarations. UI components are reactive and update automatically when state changes.

### UI Components
| Component | Syntax | Description |
| :--- | :--- | :--- |
| **Label** | `label "Text"` | Displays static or interpolated text. |
| **Button** | `button "Click Me" { ... }` | Executes actions when tapped. |
| **Input** | `input "Prompt" binding: var` | Captures user text input. |
| **Metric** | `metric "Label" value: var` | Displays a numeric value with emphasis. |
| **Chart** | `chart "Title" type: "bar" data: list` | Renders visual data representations. |
| **Camera** | `camera binding: photoVar` | Triggers native photo capture. |

---

## 5. Logic & Actions

SproutScript supports advanced control flow and state mutation within button action blocks.

### Control Flow
- **If/Else**: Conditional execution based on state values.
- **For-In**: Iterating over lists or ranges.

```sprout
button "Process" {
    if count > 10 {
        notify "Limit exceeded"
    } else {
        for item in items {
            sync item
        }
    }
}
```

### State Mutation
| Action | Syntax | Description |
| :--- | :--- | :--- |
| **Update** | `var = value` | Sets a state variable to a new value. |
| **Append** | `list += value` | Adds an item to a list. |
| **Navigate** | `-> TargetScreen` | Transitions to a different screen. |
| **Fetch** | `fetch "url" -> var` | Retrieves data from a secure endpoint. |
| **Notify** | `notify "Message"` | Sends a native system notification. |

---

## 6. Security & Sandbox

SproutScript is executed within a secure sandbox that enforces the following constraints:
1.  **Memory Limits**: Maximum source and compiled size per application.
2.  **Timeouts**: Execution time limits for logic blocks.
3.  **Domain Restricted**: Network access limited to user-approved domains.
4.  **No Arbitrary Code**: Strict grammar prevents execution of unvalidated code strings.
