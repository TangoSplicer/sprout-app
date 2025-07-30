# Sprout Demo Video Script (60 Seconds)

[0:00 - 0:05]  
🎥 (Visual: Person looking at wilting plant)  
🎙️ "I keep forgetting to water my basil..."

[0:06 - 0:10]  
🎥 Open Sprout app  
🎙️ "So I made an app for it — right on my phone."

[0:11 - 0:20]  
🎥 Type:  
```sprout
app "Plant Care" {
  start = Home
}

screen Home {
  state lastWatered = "Today"
  ui {
    label("Basil")
    label("Last watered: ${lastWatered}")
    button("Water Now") {
      lastWatered = "Today"
    }
  }
}