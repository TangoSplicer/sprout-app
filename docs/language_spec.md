# SproutScript Language Specification

## Table of Contents

1. [Overview](#overview)
2. [Lexical Structure](#lexical-structure)
3. [App Structure](#app-structure)
4. [Data Models](#data-models)
5. [Screens](#screens)
6. [UI Components](#ui-components)
7. [State Management](#state-management)
8. [Expressions](#expressions)
9. [Actions](#actions)
10. [Navigation](#navigation)

---

## Overview

SproutScript is a domain-specific language designed for creating mobile applications declaratively. It prioritizes readability, simplicity, and rapid development while maintaining the power needed for real-world applications.

### Design Principles

- **Declarative**: Describe what you want, not how to achieve it
- **Type-Safe**: Catch errors at compile time
- **Reactive**: UI automatically updates when state changes
- **Minimal**: Learn the core in minutes, master it in hours

---

## Lexical Structure

### Identifiers

Identifiers start with a letter or underscore, followed by letters, digits, or underscores.

```
screen_name
counter
my_variable
```

### String Literals

Strings are enclosed in double quotes and support interpolation.

```
"Hello, World!"
"Count: ${count}"
"Line 1\nLine 2"
```

### Numeric Literals

```
42
3.14
-10
```

### Boolean Literals

```
true
false
```

### Keywords

```
app, screen, state, ui, data, import, if, else
```

---

## App Structure

Every SproutScript application begins with an `app` declaration.

### Syntax

```sprout
app "App Name" {
    start = InitialScreen
}
```

### Example

```sprout
app "Counter App" {
    start = Home
}
```

---

## Data Models

Data models define the structure of your application's data.

### Syntax

```sprout
data ModelName {
    field_name: Type = default_value
}
```

### Supported Types

- `String` - Text data
- `Int` - Integer numbers
- `Float` - Decimal numbers
- `Boolean` - True/false values
- `Date` - Date and time
- `Custom` - User-defined types

### Example

```sprout
data Task {
    title: String
    description: String
    completed: Boolean = false
    priority: Int = 1
    dueDate: Date
}

data User {
    name: String
    email: String
    tasks: [Task]
}
```

---

## Screens

Screens represent individual views in your application.

### Syntax

```sprout
screen ScreenName(param1: Type, param2: Type) {
    state variable_name = initial_value
    
    ui {
        // UI components
    }
}
```

### Parameters

Screens can accept parameters for navigation:

```sprout
screen DetailPage(id: Int, title: String) {
    ui {
        label "${id}"
        label title
    }
}
```

### Lifecycle Events

```sprout
screen Home {
    onLaunch {
        // Runs when screen loads
    }
    
    ui {
        // UI components
    }
}
```

---

## UI Components

### Layout Containers

#### Column

Arranges children vertically:

```sprout
column {
    label "Top"
    label "Middle"
    label "Bottom"
}
```

#### Row

Arranges children horizontally:

```sprout
row {
    button "Left" { }
    button "Center" { }
    button "Right" { }
}
```

#### Stack

Overlays children on top of each other:

```sprout
stack {
    image "background.jpg"
    column {
        label "Overlay Text"
    }
}
```

### Content Components

#### Label

Displays text:

```sprout
label "Hello, World!"
label "Count: ${count}"
```

#### Title

Displays a heading:

```sprout
title "Welcome to Sprout"
```

#### Button

Clickable button with action:

```sprout
button "Click Me" {
    count = count + 1
}

button "Navigate" {
    -> NextScreen
}
```

#### Image

Displays an image:

```sprout
image "logo.png"
image "${user.avatar_url}"
```

#### Input

Text input field:

```sprout
input "Enter your name" binding: name

input "Email" binding: email
```

#### List

Renders a list of items:

```sprout
list items {
    label "${item.title}"
}
```

### Conditional Rendering

```sprout
if is_logged_in {
    label "Welcome back!"
    button "Logout" { }
} else {
    label "Please login"
    button "Login" { }
}
```

---

## State Management

State variables hold data that can change over time.

### Declaring State

```sprout
screen Home {
    state count = 0
    state message = "Hello"
    state is_visible = true
    
    ui {
        // Use state in UI
    }
}
```

### Updating State

```sprout
button "Increment" {
    count = count + 1
}

button "Toggle" {
    is_visible = !is_visible
}

button "Clear" {
    message = ""
}
```

### Reactive UI

UI automatically updates when state changes:

```sprout
screen Counter {
    state count = 0
    
    ui {
        label "Count: ${count}"
        button "Add" { count = count + 1 }
        button "Subtract" { count = count - 1 }
    }
}
```

---

## Expressions

### Arithmetic

```sprout
count + 1
price * quantity
total / items
remaining - used
```

### Comparison

```sprout
count > 10
price <= 100
name == "John"
is_done == false
```

### Boolean Logic

```sprout
is_logged_in && has_permission
is_admin || is_moderator
!is_hidden
```

### Function Calls

```sprout
add(count, 5)
format_date(date)
get_user(id)
```

### Interpolation

```sprout
"Hello, ${name}"
"Total: ${count} items"
"Date: ${format_date(now)}"
```

---

## Actions

Actions define what happens when user interacts with components.

### Button Actions

```sprout
button "Save" {
    save_task()
    show_success()
}

button "Delete" {
    remove_task(task_id)
    navigate_back()
}
```

### Event Handlers

```sprout
button "Click" { }

on Tap {
    // Handle tap
}

on Load {
    // Handle load
}
```

---

## Navigation

### Simple Navigation

```sprout
button "Go to Settings" {
    -> Settings
}
```

### Navigation with Arguments

```sprout
button "View Task" {
    -> TaskDetail(task_id, task_title)
}

screen TaskDetail(id: Int, title: String) {
    ui {
        label "${id}"
        label title
    }
}
```

### Returning Data

```sprout
screen TaskDetail(task: Task) {
    button "Save" {
        -> Home(task)
    }
}

screen Home {
    on Receive(result: Task) {
        saved_task = result
    }
}
```

---

## Complete Example

Here's a complete todo application:

```sprout
app "Todo App" {
    start = Home
}

data Todo {
    title: String
    completed: Boolean = false
}

screen Home {
    state todos = []
    state new_todo = ""
    
    ui {
        title "My Todos"
        
        input "New task" binding: new_todo
        
        button "Add" {
            todos = todos + [Todo { title: new_todo }]
            new_todo = ""
        }
        
        list todos {
            row {
                if item.completed {
                    label "✓ ${item.title}"
                } else {
                    label item.title
                }
                
                button "Done" {
                    item.completed = true
                }
            }
        }
    }
}
```

---

## Best Practices

1. **Name screens descriptively** - Use clear, meaningful names
2. **Keep screens focused** - One screen should do one thing well
3. **Use data models** - Define reusable data structures
4. **State minimalism** - Only store what you need
5. **Declarative UI** - Describe what you want, not how to build it

---

## Advanced Features

### Custom Components

```sprout
component Card(title: String, content: String) {
    column {
        title title
        label content
    }
}

screen Home {
    ui {
        Card("Welcome", "Hello!")
        Card("About", "This is Sprout")
    }
}
```

### Imports

```sprout
import "ui" from "@sprout/ui"
import "http" from "@sprout/http"

screen Home {
    state data = fetch_data()
    
    ui {
        // Use imported components
    }
}
```

---

**Next**: [Architecture Guide](architecture.md)