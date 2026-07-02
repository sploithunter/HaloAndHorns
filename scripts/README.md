# Scripts Directory

This directory contains utility scripts for code generation and project automation.

## 🔧 generate_monetization.lua

**Purpose**: Automatically generates monetization-related code from your configuration.

### What it generates:
- Network packet definitions
- Purchase handler functions  
- UI product display data
- Analytics event definitions
- Documentation

### Usage:

```bash
# From project root directory
lua scripts/generate_monetization.lua
```

### Prerequisites:
- Lua 5.1+ installed
- Run from the project root directory
- `configs/monetization.lua` must exist

### Output:
All generated files are placed in the `generated/` directory:

- `generated_network_packets.lua` - Network packet definitions for each product/pass
- `generated_purchase_handlers.lua` - Purchase processing functions
- `generated_ui_products.lua` - UI display data for shop interfaces
- `generated_analytics.lua` - Analytics event definitions
- `MONETIZATION_DOCS.md` - Auto-generated documentation

### Example Output Structure:

```
generated/
├── generated_network_packets.lua
├── generated_purchase_handlers.lua  
├── generated_ui_products.lua
├── generated_analytics.lua
└── MONETIZATION_DOCS.md
```

### When to Use:
- After modifying `configs/monetization.lua`
- Before implementing new UI components
- When setting up analytics tracking
- For generating documentation

### Integration:
The generated code can be directly integrated into your game or used as a reference for implementing monetization features.

## 🚀 Future Scripts

Additional utility scripts can be added here for:
- Asset optimization
- Configuration validation
- Test data generation
- Build automation 