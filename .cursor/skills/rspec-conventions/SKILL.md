---
name: rspec-conventions
description: RSpec style and testing conventions for the StayAhead Rails project. Use when creating, reviewing, or modifying RSpec tests.
---

# RSpec Conventions

## When to Use

Use this skill when:
- Creating new RSpec tests.
- Modifying existing specs.
- Reviewing test code.
- Refactoring test setup or expectations.

## Instructions

### General principles

- Prefer readable specs over clever specs.
- Keep examples focused on a single behaviour.
- Follow existing patterns in the test suite before introducing new ones.
- Avoid unnecessary complexity in test setup.

### Example structure

- Each `it` block should focus on one behaviour.
- Prefer one main expectation per `it` block.
- Avoid grouping unrelated expectations together.
- Use descriptive example names explaining the expected behaviour.

### Setup and test data

- Avoid creating local variables inside `it` blocks unless the value is only used once and improves readability.
- Prefer `let` for reusable test data.
- Use `let!` only when eager evaluation is required.
- Avoid unnecessary database records.
- Keep factories explicit and create only the data needed for the example.

### Subject usage

- Use `subject` when testing the main object, method, or action of the example.
- Prefer named subjects when they improve readability.

Example:

```ruby
subject(:commitment) do
  build(
    :commitment,
    start_date:,
    duration_months:,
    status:
  )
end
```

### Factories

- Prefer existing factory traits over repeating setup logic.
- Avoid adding unnecessary traits for one-off cases.
- When unsure, prefer the simplest readable implementation.

### Expectations

- Prefer behaviour-focused assertions over implementation details.
- Test outcomes rather than internal method calls unless the interaction itself is important.
- Use mocks and stubs only when they isolate an external dependency or expensive operation.

### Consistency

- Match the style and structure of existing specs in the repository.
- When unsure, prefer the simplest readable implementation.

### Project patterns

Every spec file starts with:

```ruby
# frozen_string_literal: true

require "rails_helper"
```

Request specs use shared contexts for auth and response parsing:

```ruby
RSpec.describe "Api::V1::Commitments", type: :request do
  include_context "authenticated request"
  include_context "shared config"
```

- `"authenticated request"` provides `user`, `token`, and `auth_headers`.
- `"shared config"` provides `json_response` (parsed JSON body with symbolized keys) and common user attributes.

Assert on `json_response` rather than parsing `response.body` inline:

```ruby
it "returns success status" do
  expect(response).to have_http_status(:success)
end

it "returns commitment name" do
  expect(json_response[:name]).to eq("Mortgage")
end
```

Use existing factory traits (e.g. `:one_time`, `:scheduled`, `:paused`) instead of duplicating attribute setup.
