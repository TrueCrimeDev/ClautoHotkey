# Topic: GUI Layout Agent Injection Prompt

## Category

Pattern

## Overview

An injectable role-based prompt that employs UltraThink methodology to guide AI coding agents through deep, multi-layered analysis of AutoHotkey v2 GUI layouts. Uses XML-structured progressive thinking layers and mathematical reasoning to ensure expert-level spatial design decisions.

## Key Points

- **UltraThink methodology**: Multi-layered deep analysis from surface to expert-level reasoning
- **Progressive thinking layers**: Structured cognitive escalation through complexity levels
- **Mathematical justification**: Every spatial decision requires pixel-perfect mathematical proof
- **Psychological integration**: User psychology and accessibility built into spatial reasoning
- **Expert-level output**: Transforms basic coding agents into GUI layout specialists

## Syntax and Parameters

```xml
<role>GUI_Layout_Architect</role>
<thinking_process>
  <layout_analysis>...</layout_analysis>
  <spatial_planning>...</spatial_planning>
  <validation>...</validation>
</thinking_process>
<output_requirements>
  <structure>pseudocode_first</structure>
  <validation>spatial_logic</validation>
</output_requirements>
```

## Code Examples

```xml
<!-- Injectable Prompt Template -->
<gui_layout_injection>
  <role>
    You are a GUI Layout Architect specializing in AutoHotkey v2 interfaces.
    Before writing any GUI code, you must think through the spatial design systematically.
  </role>

  <thinking_framework>
    <layout_analysis>
      <!-- Analyze requirements and constraints -->
      DETERMINE: window_purpose, user_workflow, content_hierarchy
      IDENTIFY: required_controls, relationships, priority_order
      ESTABLISH: window_boundaries, available_space, growth_direction
    </layout_analysis>

    <spatial_planning>
      <!-- Plan the spatial arrangement -->
      CALCULATE: base_window_size = content_width + margins + padding
      DEFINE: margin_system = {left: X, right: X, top: Y, bottom: Y}
      MAP: control_grid = {rows: N, columns: M, cell_spacing: Z}

      FOR each_control_group:
        POSITION: start_x, start_y based_on grid_cell
        SIZE: width, height based_on content_and_spacing
        ALIGN: relative_to neighboring_controls
        SPACE: gaps_between using_consistent_rhythm
      END FOR
    </spatial_planning>

    <validation>
      <!-- Validate the spatial logic -->
      CHECK: all_controls fit_within window_boundaries
      VERIFY: spacing_consistency across_similar_elements
      CONFIRM: visual_hierarchy through_size_and_position
      TEST: margin_respect at_window_edges
      ENSURE: logical_tab_order follows_visual_flow
    </validation>
  </thinking_framework>

  <output_requirements>
    1. Always output your <spatial_thinking> process first
    2. Use pseudocode to show layout logic before actual code
    3. Include specific pixel values in your planning
    4. Validate each positioning decision against spatial principles
  </output_requirements>
</gui_layout_injection>
```

## Implementation Notes

**Injection Strategy:**

- Insert this prompt before any GUI-related coding tasks
- Enforce the thinking process as a mandatory step
- Use XML tags to structure the agent's reasoning
- Require pseudocode output before implementation

**Spatial Thinking Process:**

1. **Layout Analysis**: Understanding purpose and requirements
2. **Spatial Planning**: Mathematical arrangement of elements
3. **Validation**: Checking spatial logic and consistency

**Agent Behavior Modification:**

- Prevents rushed layout decisions
- Ensures consistent spacing systems
- Forces consideration of user workflow
- Creates traceable design reasoning

**Common Integration Points:**

- Embed in system prompts for coding agents
- Activate when GUI-related keywords detected
- Trigger on `Gui.Add()` or layout-related requests
- Use as validation step before code generation

## Related AHK Concepts

- GUI margin and padding systems
- Control positioning mathematics
- Visual hierarchy principles
- Window boundary calculations
- Responsive layout patterns

## Tags

#AutoHotkey #GUI #Agent #Prompt #Layout #UltraThink #XML #SystemPrompt #Injection #DeepAnalysis #Mathematical #Psychology
