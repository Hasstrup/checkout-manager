# (DEMO) Checkout Gem: Inventory and Discount System
## Introduction
This repository contains a **checkout** gem that is capable of reading stored **inventory items** and **discounts**. Using any combination of available items, it computes the **cart total** and presents the **pricing/discount breakdowns**.

Main implementation contained here: https://github.com/Hasstrup/checkout-manager/pull/1

It achieves this by exposing a `Checkout::Models::Cart` class. Instances of this class are able to:
- **Scan inventory items** (via `#bulk_scan`)
- **Compute discounts**, sum prices, and display the final total along with discount breakdowns (via `#total`)
More on this further down in the description.
---
## Installation & Getting Started
1. Checkout this [PR](https://github.com/Hasstrup/checkout-manager/pull/1)
1. Pull the matching branch
2. Install the gems using `bundle install`
3. Launch the gem console using `bin/console`
4. Run some examples in the console by copying and pasting the code below:
    ```ruby
    examples = [
      "A, B, C", 
      "B, A, B, B, A", 
      "C, B, A, A, C, B, C"
    ]
    # Optionally, you can pass a yml file path during initialization
    # By default, the rules in /lib/checkout/core/inventory.yml are used
    examples.map do |example_entry|
      Checkout::Models::Cart.new.bulk_scan(example_entry).total
    end
    ```
