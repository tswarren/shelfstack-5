# Receipt typography and column alignment

**Applies to:** browser/PDF renderers for POS printed documents (`docs/design/pos-printing/`)
**Does not apply to:** a future raw ESC/POS thermal renderer, if one is ever built — see §4.

---

## 1. Decision

Use a proportional font for receipt body text. Do not use a monospace font to achieve column alignment.

Reasoning: monospace-grid alignment (padding strings with spaces to line up character columns) is a workaround for raw character-stream printing, where there's no layout engine. The browser/PDF renderer target has a real layout engine — CSS grid or table — so alignment is a layout problem, not a font problem. Solving it with a font constrains legibility for a benefit CSS already provides for free.

## 2. The pattern

Two techniques, used together:

1. **Grid layout for line-item rows** — description column flexible, quantity/price/total columns fixed-width and right-aligned. This is what actually produces column alignment; it works with any font.
2. **`font-variant-numeric: tabular-nums`** on any element containing a price, quantity, or total — makes every digit equal-width within a proportional font, so numbers of different lengths still line up vertically in their column.

## 3. Reference CSS

```css
.receipt {
  font-family: var(--receipt-font-sans, system-ui, sans-serif);
  font-size: 13px;
  line-height: 1.6;
  width: 320px; /* ~80mm thermal target; not a business invariant, see common contract §11.5 */
}

.receipt-line {
  display: grid;
  grid-template-columns: 1fr auto;
  gap: 8px;
}

.receipt-line .amount,
.receipt-total .amount,
.receipt-tax .amount {
  font-variant-numeric: tabular-nums;
  text-align: right;
}

.receipt-line.return .amount::before {
  content: "-"; /* direction indicated explicitly, never by color alone */
}

.receipt-totals {
  border-top: 1px solid var(--receipt-rule, #000);
  margin-top: 8px;
  padding-top: 8px;
}

.receipt-totals .receipt-line {
  font-weight: 600; /* only the grand total gets weight emphasis */
}
```

```html
<div class="receipt">
  <div class="receipt-line">
    <span>The Left Hand of Darkness</span>
    <span class="amount">$19.99</span>
  </div>
  <div class="receipt-line">
    <span>Member discount</span>
    <span class="amount">-$2.00</span>
  </div>
  <div class="receipt-totals">
    <div class="receipt-line">
      <span>Total</span>
      <span class="amount">$17.99</span>
    </div>
  </div>
</div>
```

## 4. Where this doesn't apply

A raw ESC/POS thermal renderer (not currently in scope — no renderer target beyond browser/PDF exists today) writes a character stream with no layout engine available. If one is ever built, it needs its own text-formatting logic — fixed-width padding to a known column count — implemented entirely inside that renderer. It should not change the structured document facts or the browser renderer above; per the common contract's renderer boundary, one structured document already supports multiple renderers without redefining business semantics.

## 5. Font choice

Any system-ui / platform-default sans stack that supports `tabular-nums` works — this is a standard OpenType feature (`tnum`), not a specialty font requirement. No custom font license or web-font load is needed for correctness; a specific brand typeface is a Store-presentation choice, not something this pattern depends on.