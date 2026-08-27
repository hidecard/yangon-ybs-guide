# Mockup review notes

Reviewed `feature_graphic_1024x500.png` and `03_burmese_assistant_1080x1920.png`.

The overall navy/amber/white composition, portrait device framing, content hierarchy, and Burmese copy are suitable as a first store asset set. The feature graphic has a critical rendering defect: the bus icon area appears as a blank white square because the RGBA icon was drawn with a non-transparent background and copied with `ImageDraw.bitmap`. The phone header in the portrait mockup has the same icon-copy issue, leaving a visible line/blank mark instead of the bus symbol. The mockup generator must composite the icon using an alpha-aware paste operation and regenerate all assets before delivery.

The portrait mockup text is readable at the generated 1080x1920 dimensions. Some Burmese glyphs and English labels are intentionally small but remain secondary; the main headline and feature callouts have adequate hierarchy. After the icon fix, perform one targeted visual re-check of the feature graphic and one portrait screenshot.

## Re-check after fix

The feature graphic and Burmese Assistant portrait mockup were regenerated and reviewed again. The bus symbol now renders correctly with alpha compositing; the earlier blank white square is gone. The navy/amber palette, centered safe-area composition, and 1024x500 feature graphic dimensions are suitable for Play Store upload preparation. The portrait mockup is 1080x1920, has a visible app header/icon, a Burmese Assistant conversation, a route result, and a visible input/send affordance. No further critical visual defect was observed in this targeted pass.
