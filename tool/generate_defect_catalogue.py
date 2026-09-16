#!/usr/bin/env python3
"""Generates the controlled defect catalogue used by both the Flutter
app and the Firebase Functions AI gateway from one canonical, hand
transcribed table (below), sourced from
"DEFECT_REPORT_LIST.xlsx - DEFECT LIST.pdf".

This is the SINGLE SOURCE OF TRUTH for the defect catalogue. To change
the catalogue: edit CATALOGUE below, then re-run this script — it
regenerates both:
  - lib/core/inspection/entities/defect_catalogue_data.dart
  - functions/src/ai/defect_catalogue_data.ts

Run from the repo root: `python3 tool/generate_defect_catalogue.py`

IDs are derived deterministically from position (main element index,
component index, defect index within component) rather than from
slugified text, so they stay stable even if wording is corrected later
(fixing a typo in a defect description does not change its id).
"""
import json
import re

# Each top-level tuple is (main_element_name, components).
# Each component is (component_name, defects).
# Each defect is (description, corrective_action) — corrective_action
# is None where the source document left the cell genuinely blank
# (preserved as-is rather than invented, per spec).
CATALOGUE = [
    ("Door", [
        ("Door Bell Switch", [
            ("Door bell is contaminated with stain",
             "Remove the stain and clean the affected area. Make sure the "
             "finishing is good."),
            ("Door bell switch is damaged/not functioning properly",
             "Replace with a new door bell switch. Test the functionality"),
            ("Door bell switch is loose",
             "Reinstall the door bell switch. Make sure it is firm and "
             "tightened."),
            ("Door bell switch is slanted",
             "Readjust the door bell switch alignment. Make sure the "
             "finishing is good"),
            ("Visible gap between door bell switch and wall",
             "Seal off the gap with sealant/filler. Make sure the finishing "
             "is good"),
        ]),
        ("Door Closer", [
            ("Door closer is contaminated with stain",
             "Remove the stain and clean the affected area. Make sure the "
             "finishing is good."),
            ("Door closer is loose",
             "Reinstall the door closer. Make sure it is tightened. Test "
             "the functionality"),
            ("Door closer is rusty",
             "Replace to a new door closer. Test the functionality"),
            ("Door closer produces creaking sound when opened/closed",
             "Reinstall the door closer. Test the functionality"),
            ("Door slams/stops half way when closed. Door closer is not "
             "functioning properly",
             "Readjust the door closer alignment. Test for functionality"),
        ]),
        ("Door Frame", [
            ("Aluminum door frame is damaged/chipped/scratched",
             "Sand down the dented area to the bare metal. Apply auto body "
             "filler until it is flushed to the surface. Repaint the area "
             "with same colour coded door paint."),
            ("Door frame is contaminated with stain",
             "Remove the stain and clean the affected area. Make sure the "
             "finishing is good."),
            ("Door frame is not aligned",
             "Readjust the door frame alignment. Test for functionality"),
            ("Door frame is rusty",
             "Chip off the rust, apply anti-rust coating and repaint with "
             "the same colour coded paint"),
            ("Gap between door frame and wall/floor is not properly sealed "
             "off",
             "Seal off the gap with silicon/filler. Make sure the finishing "
             "is good."),
            ("Missing rubber cover on the door frame",
             "Install the rubber cover. Make sure it is firm and tightened. "
             "Test the functionality"),
            ("Poor paint finishing on the door frame",
             "Sand down the affected area. Repaint with the same colour "
             "coded paint. Make sure the surface is smooth and even"),
            ("Visible gap between door frame panels",
             "Seal off the gap with silicone/filler. Make sure the "
             "finishing is good"),
            ("Wooden door frame is damaged/chipped/scratched",
             "Fill the chipped area with wood filler. Sand down and "
             "repaint with the same colour coded paint"),
        ]),
        ("Door Hinge", [
            ("Door hinge installation is poor/slanted/gap/loose",
             "Reinstall the hinge. Make sure the finishing is good. Test "
             "the functionality"),
            ("Door hinge is contaminated with stain",
             "Remove the stain and clean the affected area. Make sure the "
             "finishing is good."),
            ("Door hinge is rusty",
             "Replace with a new door hinge. Test the functionality"),
            ("Door hinge produces a creaking sound when opened/closed",
             "Apply lubricant or replace the door hinge if required. Test "
             "the functionality"),
            ("Missing screw on the door hinge",
             "Install the missing screw. Make sure it is tightened and "
             "firm. Test for functionality"),
        ]),
        ("Door Knob/Handle", [
            ("Door handle is damaged/chipped/scratched",
             "Replace with a new door handle. Test the functionality"),
            ("Door handle is loose",
             "Reinstall the door handle. Make sure it is tightened. Test "
             "the functionality"),
            ("Door handle is not functioning properly",
             "Replace with a new door knob/handle. Test the functionality"),
            ("Door handle is contaminated with stain",
             "Remove the stain and clean the affected area. Make sure the "
             "finishing is good."),
            ("Door knob/handle is rusty",
             "Replace with a new door knob/handle. Test for functionality"),
        ]),
        ("Door Latch", [
            ("Door cannot latch properly. Door latch does not align to "
             "the door strike plate",
             "Readjust the door strike plate alignment. Test the "
             "functionality"),
            ("Door latch is contaminated with stain",
             "Remove the stain and clean the affected area. Make sure the "
             "finishing is good."),
            ("Door latch is stuck to the door strike plate when closed",
             "Readjust the door strike plate alignment. Test the "
             "functionality"),
            ("Door strike plate does not flush to the door leaf. Poor "
             "installation",
             "Readjust the door strike plate alignment. Make sure the "
             "finishing is good."),
        ]),
        ("Door Leaf", [
            ("Door in contaminated with stain",
             "Remove the stain and clean the affected area. Make sure the "
             "finishing is good."),
            ("Door leaf clashes with others elements when closed",
             "Readjust the door leaf alignment. Make sure it can be "
             "opened/closed smoothly."),
            ("Door leaf does not flush with door frame when closed",
             "Readjust the door leaf alignment. Make sure it flushes with "
             "the door frame when closed."),
            ("Door leaf is cracked/damaged/chipped",
             "Fill the chipped area with wood filler. Sand down and "
             "repaint with same colour coded paint"),
            ("Door leaf is not aligned/rattles when closed",
             "Readjust the door leaf alignment. Make sure it is flushed to "
             "the door frame when closed. Test for functionality."),
            ("Insufficient rubber seal length",
             "Install the door seal with sufficient length. Make sure it "
             "is firm and the finishing is good."),
            ("Poor paint finishing on the door leaf. Top/bottom part of "
             "the door is not painted",
             "Sand down the affected area. Repaint with the same colour "
             "coded paint. Make sure the surface is smooth and even."),
        ]),
        ("Door Lockset", [
            ("Door lockset screw is rusty",
             "Replace with the same screw type. Make sure it is firm and "
             "tightened. Test for functionality"),
            ("Keys provided do not match with the door lockset/unable to "
             "use",
             "Provide the keys that match with the door lockset."),
        ]),
        ("Door Stopper", [
            ("Door stopper is contaminated with stain",
             "Remove the stain and clean the affected area. Make sure the "
             "finishing is good."),
            ("Door stopper is loose",
             "Reinstall the door stopper. Make sure it is firm and "
             "tightened."),
            ("Door stopper is not functioning properly",
             "Replace with a new door stopper. Test the functionality"),
            ("Door stopper is rusty",
             "Replace with a new door stopper. Make sure it is firm and "
             "tightened."),
            ("Missing door stopper",
             "Install the door stopper. Make sure it is firm and "
             "tightened. Test the functionality"),
            ("Poor installation of door stopper",
             "Reinstall the door stopper. Make sure it is firm and "
             "tightened."),
        ]),
        ("Grill Door", [
            ("Grill door is dented/chipped/scratched",
             "Sand down the dented area to the bare metal. Apply auto "
             "body filler until it is flushed to the surface. Repaint the "
             "area with same colour coded door paint."),
            ("Door grill is not aligned",
             "Reinstall the door grill. Make sure it is aligned and test "
             "for functionality."),
            ("Grill is contaminated with stain",
             "Remove the stain and clean the affected area. Make sure the "
             "finishing is good."),
            ("Latch hole is missing/misaligned",
             "Provide the latch hole. Test the functionality."),
            ("Missing lock pin on the grill door hinge",
             "Provide and install the lock pin. Make sure it tightened. "
             "Test for grill door functionality."),
            ("Poor paint finishing on the grill door/paint peeled off",
             "Sand down the affected area. Repaint with the same colour "
             "coded paint. Make sure the surface is smooth and even."),
        ]),
        ("Sliding Door Frame", [
            ("Gap between sliding door frame and wall is not properly "
             "sealed off",
             "Seal off the gap with sealant/filler. Make sure the "
             "finishing is good"),
            ("Missing rubber seal/rubber seal is peeled off",
             "Install the rubber seal. Make sure the finishing is good"),
            ("Missing screw on the sliding door frame",
             "Install with the same screw type. Make sure it is firm and "
             "tightened. Test for functionality"),
            ("Poor paint finishing on the sliding door frame",
             "Sand down the affected area. Repaint with the same colour "
             "coded paint. Make sure the surface is smooth and even."),
            ("Sliding door frame is damaged/chipped/scratched",
             "Sand down the dented area to the bare metal. Apply auto "
             "body filler until it is flushed to the surface. Repaint the "
             "area with same colour coded door paint."),
            ("Sliding door frame is contaminated with stain",
             "Remove the stain and clean the affected area. Make sure the "
             "finishing is good."),
            ("Sliding door frame is not aligned",
             "Readjust the sliding door frame alignment. Test for "
             "functionality."),
            ("Sliding door frame is rusty",
             "Chip off the rust, apply anti-rust coating and repaint with "
             "the same colour coded paint"),
        ]),
        ("Sliding Door Glass", [
            ("Sliding door glass is contaminated with stain",
             "Remove the stain and clean the affected area. Make sure the "
             "finishing is good."),
            ("Sliding door glass is damaged/chipped/scratched",
             "Replace with a new glass panel. Make sure the finishing is "
             "good."),
        ]),
        ("Sliding Door Panel", [
            ("Gap between sliding door panels is not properly sealed off",
             "Seal off the gap with sealant/filler. Make sure the "
             "finishing is good"),
            ("Missing rubber cover on the door frame",
             "Install the rubber cover. Make sure it is firm and "
             "tightened. Test the functionality"),
            ("Missing rubber seal/rubber seal is peeled off",
             "Install the rubber seal. Make sure the finishing is good."),
            ("Poor paint finishing on the sliding door panel",
             "Sand down the affected area. Repaint with the same colour "
             "coded paint. Make sure the surface is smooth and even"),
            ("Sliding door is damaged/chipped/scratched",
             "Sand down the dented area to the bare metal. Apply auto "
             "body filler until it is flushed to the surface. Repaint the "
             "area with same colour coded door paint."),
            ("Sliding door panel is contaminated with stain",
             "Remove the stain and clean the affected area. Make sure the "
             "finishing is good."),
            ("Sliding door panel is not aligned",
             "Readjust the sliding door panel alignment. Test for "
             "functionality"),
            ("Sliding door panel is not functioning properly",
             "Readjust the sliding door panel alignment. Test for "
             "functionality"),
            ("Sliding door panel is rusty",
             "Chip off the rust, apply anti-rust coating and repaint with "
             "the same colour coded paint"),
            ("Sliding door panel produces a creaking sound when opened/and "
             "closed",
             "Apply lubricant or reinstall the door panel if required. "
             "Test the functionality"),
        ]),
    ]),
    ("Window", [
        ("Window Awning", [
            ("Poor painting finishing on the window awning",
             "Sand down the affected area. Repaint with the same colour "
             "coded paint. Make sure the surface is smooth and even."),
            ("Window awning is contaminated with stain",
             "Remove the stain and clean the affected area. Make sure the "
             "finishing is good."),
            ("Window awning is damaged/chipped/scratched",
             "Sand down the affected area. Repaint with the same colour "
             "coded paint. Make sure the surface is smooth and even."),
            ("Window awning is not aligned/slanted",
             "Readjust the window awning alignment. Make sure the "
             "finishing is good."),
        ]),
        ("Window Frame", [
            ("Gap between window frame and wall is not properly sealed "
             "off",
             "Seal off the gap with sealant/filler. Make sure the "
             "finishing is good"),
            ("Insufficient rubber seal on the window frame",
             "Replace with a new rubber seal with sufficient length. Make "
             "sure the finishing is good."),
            ("Missing rubber seal/rubber seal is peeled off",
             "Install the new rubber seal. Make sure the finishing is "
             "good."),
            ("Missing screw on the window frame",
             "Install with the same screw type. Make sure it is tightened "
             "and firm. Test for functionality."),
            ("Poor paint finishing on the window frame",
             "Sand down the affected area. Repaint with the same colour "
             "coded paint. Make sure the surface is smooth and even."),
            ("Poor window frame installation",
             "Reinstall the window frame. Make sure the finishing is "
             "good."),
            ("Visible gap between window frame",
             "Seal off the gap with silicone/filler. Make sure the "
             "finishing is good."),
            ("Window frame are contaminated with stain",
             "Remove the stain and clean the affected area. Make sure the "
             "finishing is good."),
            ("Window frame is damaged/chipped/scratched",
             "Sand down the dented area to the bare metal. Apply auto "
             "body filler until it is flushed to the surface. Repaint the "
             "area with same colour coded window paint."),
            ("Window frame is not aligned/slanted",
             "Readjust the window frame alignment. Test for functionality"),
            ("Window frame is rusty",
             "Chip off the rust, apply anti-rust coating and repaint with "
             "the same colour coded paint."),
        ]),
        ("Window Glass", [
            ("Window glass are contaminated with stain",
             "Remove the stain and clean the affected area. Make sure the "
             "finishing is good."),
            ("Window glass is damaged/chipped/scratched",
             "Replace with a new glass panel. Make sure the finishing is "
             "good."),
        ]),
        ("Window Handle", [
            ("Missing screw on the window handle",
             "Install the missing screw. Make sure it is tightened and "
             "firm. Test for functionality"),
            ("Rusty screw on window handle",
             "Replace with the same screw type. Make sure it is firm and "
             "tightened"),
            ("Window handle is loose",
             "Reinstall with the new window handle. Make sure it is "
             "tightened. Test for functionality"),
            ("Window handle is not functioning properly",
             "Replace with a new window handle. Test for functionality"),
            ("Window handle are contaminated with stain",
             "Remove the stain and clean the affected area. Make sure the "
             "finishing is good."),
            ("Window handle is damaged/chipped/scratched",
             "Replace with a new window handle. Test for functionality"),
        ]),
        ("Window Hinge", [
            ("Missing screw on the window hinge",
             "Install the missing screw. Make sure it is tightened and "
             "firm. Test for functionality"),
            ("Window hinge installation is poor/loose",
             "Reinstall the hinge. Make sure the finishing is good. Test "
             "for functionality"),
            ("Window hinge is contaminated with stain",
             "Remove the stain and clean the affected area. Make sure the "
             "finishing is good."),
            ("Window hinge is rusty",
             "Replace with a new window hinge. Test for window "
             "functionality"),
            ("Window hinge is stuck. Window cannot be closed properly.",
             "Reinstall the hinge. Make sure the finishing is good. Test "
             "for functionality"),
            ("Window hinge produces a creaking sound when opened/closed.",
             "Apply lubricant or replace the window hinge if required. "
             "Tests for functionality"),
        ]),
        ("Window Leaf", [
            ("Insufficient rubber seal on the window leaf",
             "Replace with a new rubber seal with sufficient length. Make "
             "sure the finishing is good."),
            ("Missing rubber seal/rubber seal is peeled off",
             "Install the rubber seal. Make sure the finishing is good."),
            ("Poor paint finishing on the window leaf",
             "Sand down the affected area. Repaint with the same colour "
             "coded paint. Make sure the surface is smooth and even."),
            ("Window cannot be closed properly",
             "Readjust the window alignment. Make sure it is flushed to "
             "the frame when closed. Test for functionality"),
            ("Window leaf clashes with wall when opened/closed",
             "Readjust the window leaf alignment. Test for functionality"),
            ("Window leaf is contaminated with stain",
             "Remove the stain and clean the affected area. Make sure the "
             "finishing is good."),
            ("Window leaf is damaged/chipped/scratched",
             "Sand down the affected area to the bare metal. Apply auto "
             "body filler until it is flushed to the surface. Repaint the "
             "area with same colour coded window paint."),
            ("Window leaf is not aligned with the window frame. "
             "Inconsistent gap when close.",
             "Readjust the window alignment. Make sure it is flushed to "
             "the frame when closed. Test for functionality"),
        ]),
    ]),
    ("Wall", [
        ("Concrete Wall", [
            ("Gap is not properly sealed off",
             "Seal off the gap with silicone/filler. Make sure the "
             "finishing is good."),
            ("Hairline crack on the wall",
             "Cut along the hairline crack, install fibre/wire mesh, fill "
             "the area with skim filler, sand down the surface and "
             "repaint with same colour coded paint. Make sure the "
             "finishing is good."),
            ("Poor skim/paint finishing",
             "Apply skim coat and sand down the affected area."),
            ("Wall is bulging",
             "Chip off the affected area, apply Portland cement, fill the "
             "area with skim filler, sand down the surface and repaint "
             "with same colour coded paint. Make sure the finishing is "
             "good."),
            ("Wall is chipped",
             "Fill the affected area with skim filler, sand down and "
             "repaint with same colour coded paint. Make sure the "
             "finishing is good."),
            ("Wall in contaminated with stain",
             "Remove the stain and clean the affected area. Make sure the "
             "finishing is good."),
            ("Wall is uneven/not straight",
             "Chip off the affected area, apply Portland cement, fill the "
             "area with skim filler, sand down the surface and repaint "
             "with same colour coded paint. Make sure the finishing is "
             "good."),
            ("Wall squareness exceeds tolerance",
             "Readjust the wall alignment. Make sure the wall alignment "
             "is within the acceptable tolerance <4mm"),
            ("Watermark stain spotted on the wall",
             "Further investigation must be made to check on the source "
             "of leakage. This problem must be rectified according to the "
             "approved method statement from the consultant/SO"),
        ]),
        ("Wall Tile", [
            ("Inconsistent grout colour tone",
             "Grout the gap between the tiles with the same tile gap "
             "filler tone. Make sure the gap is fully sealed"),
            ("Tile gap is not properly sealed off. Poor finishing",
             "Grout the gap between the tiles with tile gap filler. Make "
             "sure the gap is fully sealed and the finishing is good."),
            ("Wall tile/tile grout is contaminated with stain/scratched",
             "Remove the stain and clean the affected area. Make sure the "
             "finishing is good."),
            ("Wall tile inconsistent colour tone/Wall tile is "
             "damaged/chipped/hollow/uneven/not straight",
             "Replace with a new tile with the same colour coded. Ensure "
             "the tile alignment is consistent and tile adhesive is fully "
             "spread. Test for tile hollowness."),
            ("Wall tile is not aligned/lippage",
             "Readjust the tile alignment. Make sure it is consistent and "
             "the finishing is good"),
            ("Wall tile opening is not sealed off",
             "Seal off the gap with sealant/filler. Make sure the "
             "finishing is good."),
        ]),
    ]),
    ("Floor", [
        ("Timber Floor", [
            ("Timber floor are contaminated with stain.",
             "Remove the stain and clean the affected area. Make sure the "
             "finishing is good."),
            ("Floor board has different colour tone",
             "Replace with the same colour coded floor board. Make sure "
             "the surface is even, the alignment is consistent and the "
             "finishing is good."),
            ("Floor board is damaged/chipped/scratched",
             "Replace with the same colour coded floor board. Make sure "
             "the surface is even, the alignment is consistent and the "
             "finishing is good."),
            ("Floor board is uneven/lippage",
             "Reinstall the floor panel. Make sure the surface is even, "
             "the alignment is consistent and the finishing is good."),
            ("Floor board is wobbly and not firm",
             "Reinstall the floor panel. Make sure the surface is even, "
             "the alignment is consistent and the finishing is good."),
            ("Floor coating finishing is poor/faded/not properly done",
             "Further investigation must be made by the Developer to "
             "check on the source of problem. This problem must be "
             "rectified according to the approved method statement from "
             "the Consultant/S.O."),
            ("Gap between floor board and door frame is not properly "
             "sealed off",
             "Grout the gap with gap filler. Make sure the gap is fully "
             "sealed and the finishing is good."),
            ("Gap between floor board is not sealed off",
             "Grout the gap between the floor board with sealant/filler. "
             "Make sure the gap is fully sealed and the finishing is "
             "good."),
            ("Gap between floor skirting and wall is not sealed off",
             "Grout the gap with gap filler/sealant. Make sure the gap is "
             "fully sealed and the finishing is good."),
            ("Inconsistent gap between floor board",
             "Readjust the floor board alignment. Make sure the finishing "
             "is good."),
            ("Visible gap between floor skirt and floor board when load "
             "is applied",
             "Grout the gap with gap filler/sealant. Make sure the gap is "
             "fully sealed and the finishing is good."),
        ]),
        ("Wood Skirting", [
            ("Wood skirting is contaminated with stains.",
             "Remove the stain and clean the affected area. Make sure the "
             "finishing is good."),
            ("Gap between skirting and wall is not properly sealed off",
             "Grout the gap between the wall with gap filler. Make sure "
             "the gap is fully sealed and the finishing is good."),
            ("Poor finishing on the wood skirting",
             "Reinstall the wood skirting. Make sure it is firm and the "
             "finishing is good. Sand down the affected area. Repaint "
             "with the same colour coded paint. Make sure the surface is "
             "smooth and even."),
            ("Wood skirting gap is not properly sealed off. Poor "
             "finishing",
             "Grout the gap with gap filler. Make sure the gap is fully "
             "sealed and the finishing is good."),
            ("Wood skirting has inconsistent colour tone",
             "Sand down the affected area. Repaint with the same colour "
             "coded paint. Make sure the surface is smooth and even."),
            ("Wood skirting is damaged/chipped/cracked",
             "Replace with a new skirting with the same colour coded. "
             "Ensure the tile alignment is consistent and adhesive is "
             "fully spread."),
            ("Wood skirting lippage exceeds tolerance",
             "Readjust the skirting alignment. Make sure the surface is "
             "even and the tile adhesive is fully spread."),
            ("Wood skirting paint peeled off",
             "Repaint the affected area with the same colour coded paint. "
             "Make sure the finishing is good."),
        ]),
        ("Floor Tiles", [
            ("Floor tile are contaminated with stain/scratched.",
             "Remove the stain and clean the affected area. Make sure the "
             "finishing is good."),
            ("Floor tile inconsistent colour tone.",
             "Replace with a new tile with the same colour tone. Ensure "
             "the tile alignment is consistent and tile adhesive is fully "
             "spread. Test the tile hollowness."),
            ("Floor tile is chipped/damaged.",
             "Replace with a new tile with the same colour tone. Ensure "
             "the tile alignment is consistent and tile adhesive is fully "
             "spread. Test the tile hollowness."),
            ("Floor tile is faded",
             "Replace with a new tile with the same colour tone. Ensure "
             "the tile alignment is consistent and tile adhesive is fully "
             "spread. Test the tile hollowness."),
            ("Floor tile is hollow.",
             "Replace with a new tile with the same colour tone. Ensure "
             "the tile alignment is consistent and tile adhesive is fully "
             "spread. Test the tile hollowness."),
            ("Floor tile is uneven/not straight.",
             "Replace with a new tile with the same colour tone. Ensure "
             "the tile alignment is consistent and tile adhesive is fully "
             "spread. Test the tile hollowness."),
            ("Floor tile lippage exceeds tolerance",
             "Readjust the tile alignment. Make sure the surface is even "
             "and tile adhesive is fully spread. Test for tile hollowness "
             "and evenness."),
            ("Gap between floor tile and door frame is not properly "
             "sealed off.",
             "Grout the gap with gap filler. Make sure the gap is fully "
             "sealed and the finishing is good."),
            ("Inconsistent grout colour tone.",
             "Grout the gap between the tiles with the same tile gap "
             "filler tone. Make sure the gap is fully sealed and the "
             "finishing is good."),
            ("Tile edge is sharp",
             "Chamfer the tile edge. Make sure the finishing is smooth "
             "and good."),
            ("Tile gap is not properly sealed off. Poor finishing",
             "Grout the gap between the tiles with tile gap filler. Make "
             "sure the gap is fully sealed and the finishing is good."),
            ("Water remains stagnant on one side of the floor.",
             "Readjust the floor tiles gradient. Make sure the finishing "
             "is good and the gradient is directed towards the floor "
             "trap. Test with spirit level."),
        ]),
        ("Tiles Skirting", [
            ("Tiles skirting is contaminated with stain.",
             "Remove the stain and clean the affected area. Make sure the "
             "finishing is good."),
            ("Inconsistent grout colour tone",
             "Grout the between the tiles with the same tile gap filler "
             "tone. Make sure the gap is fully sealed and the finishing "
             "is good."),
            ("Tile gap is not properly sealed off. Poor finishing",
             "Grout the between the tiles with the tile gap filler tone. "
             "Make sure the gap is fully sealed and the finishing is "
             "good."),
            ("Tile skirting inconsistent colour tone",
             "Replace with a new tile with the same colour code. Ensure "
             "the tile alignment is consistent and the tile adhesive is "
             "fully spread. Test for tile hollowness."),
            ("Tiles skirting is damaged/chipped",
             "Replace with a new tile with the same colour code. Ensure "
             "the tile alignment is consistent and the tile adhesive is "
             "fully spread. Test for tile hollowness."),
            ("Tile skirting is hollow",
             "Replace with a new tile with the same colour code. Ensure "
             "the tile alignment is consistent and the tile adhesive is "
             "fully spread. Test for tile hollowness."),
            ("Tile skirting lippage exceeds tolerance",
             "Readjust the tile alignment. Make sure the surface is even "
             "and tile adhesive is fully spread. Test for tile hollowness "
             "and evenness."),
        ]),
    ]),
    ("Roof", [
        ("Roof Tiles", [
            ("Roof tiles are chipped/damaged",
             "Replace with a new roof tile. Make sure it is aligned and "
             "the finishing is good."),
            ("Roof tile is not aligned/not installed properly",
             "Reinstall the roof tile. Make sure it is aligned and the "
             "finishing is good."),
        ]),
    ]),
    ("Ceiling", [
        ("Ceiling", [
            ("Ceiling bracket is rusty",
             "Replace with a new ceiling bracket. Make sure it is firm "
             "and tightened."),
            ("Ceiling is chipped",
             "Filled the affected area with a skim filler, sand down and "
             "repaint with same colour coded paint. Ensure surface is "
             "smooth and even."),
            ("Ceiling is uneven/not straight",
             "Further investigation must be made by the Developer to "
             "check on the source of problem. This problem must be "
             "rectified according to the approved method statement from "
             "the Consultant/SO."),
            ("Construction debris left above the ceiling",
             "Remove the debris. Make sure the area is clean."),
            ("Gap between ceiling and wall is not properly sealed off",
             "Seal off the gap with silicon/filler. Make sure the "
             "finishing is good."),
            ("Hairline crack on the ceiling",
             "Cut along the hairline crack, install fibre/wire mesh, fill "
             "the area with skim filler, sand down the surface and "
             "repaint with same colour coded paint."),
            ("Missing water drip grooveline/Poor water drip grooveline "
             "finishing",
             "Further investigation must be made by the Developer to "
             "check on the source of problem. This problem must be "
             "rectified according to the approved method statement from "
             "the Consultant/SO."),
            ("Poor skim/paint finishing",
             "Apply skim coat and sand down the affected area. Repaint "
             "with the same colour coded paint and ensure the surface is "
             "smooth and even."),
            ("Watermark stain spotted on the ceiling",
             "Further investigation must be made by the Developer to "
             "check on the source of problem. This problem must be "
             "rectified according to the approved method statement from "
             "the Consultant/SO."),
        ]),
    ]),
    ("Plumbing", [
        ("Bottle Trap", [
            ("Bottle trap is clogged/slow draining",
             "Remove any debris and clear the bottle trap. Test for water "
             "flow. Replace if required."),
            ("Bottle trap is damaged",
             "Replace with a new bottle trap. Make sure the height is "
             "right. Test for water flow and water leakage."),
            ("Bottle trap is leaking",
             "Check the source of leakage. Apply Teflon tape around the "
             "pipe thread. Replace if required. Test for water leakage."),
            ("Bottle trap is loose",
             "Reinstall the bottle trap. Make sure it is firm and "
             "tighten. Apply Teflon tape around the pipe thread and test "
             "for water leakage."),
        ]),
        ("Discharge Pipe", [
            ("Discharge pipe is clogged/slow draining",
             "Remove any debris and clear the discharge pipe. Test for "
             "water flow."),
            ("Discharge pipe is damage",
             "Replace with a new discharge pipe. Make sure the gradient "
             "is right. Test for water flow and water leakage."),
            ("Discharge pipe is leaking",
             "Further investigation must be made by the Developer to "
             "check on the source of problem. This problem must be "
             "rectified according to the approved method statement from "
             "the Consultant/SO."),
            ("Discharge pipe is slanted/reversed gradient",
             "Reinstall the discharge pipe. Make sure the gradient "
             "towards the right direction. Test with spirit level and "
             "water flow."),
        ]),
    ]),
    ("Electrical Fitting", [
        ("Distribution Board", [
            ("DB cover is damaged",
             "Replace with a new DB cover. Make sure the finishing is "
             "good."),
            ("DB is not properly installed",
             "Reinstall the DB. Make sure the finishing is good."),
            ("Earthing for metal DB cover leakage protection is not "
             "provided",
             "Install the earthing link for safety purpose."),
            ("Gap between DB and wall is not properly sealed off",
             "Seal off the gap with sealant/filler. Make sure the "
             "finishing is good."),
            ("Missing blank plate cover on the unused slot",
             "Install the blank plate cover on the unused slot. Make sure "
             "the finishing is good."),
            ("Missing screw on the DB cover",
             "Install the missing screw. Make sure it is tightened and "
             "firm. Test for functionality."),
            ("Single line diagram and MCB label are not provided",
             "Provide the Single Line Diagram and MCB label for owner's "
             "future maintenance purpose."),
        ]),
    ]),
    ("Sanitary Fitting", [
        ("Shower Head", [
            ("Missing shower head", None),
            ("No hot water supply",
             "Further investigation must be made by the Developer to "
             "check on the source of problem. This problem must be "
             "rectified according to the approved method statement from "
             "the Consultant/SO."),
            ("Shower head is chipped/damaged/dented",
             "Reinstall the shower head. Test for functionality and "
             "leakage"),
            ("Shower head is leaking", None),
            ("Shower head is loose",
             "Reinstall the shower head. Make sure it is tightened and "
             "firm. Test for functionality and leakage"),
            ("Shower head is not functioning properly",
             "Replace with a new shower head. Test for functionality"),
            ("Shower head is rusty",
             "Replace with a new shower head. Test for functionality"),
            ("Shower head is slanted",
             "Readjust the shower head alignment. Make sure the finishing "
             "is good."),
            ("Shower head water pressure is low",
             "Further investigation must be made by the Developer to "
             "check on the source of problem. This problem must be "
             "rectified according to the approved method statement from "
             "the Consultant/SO."),
        ]),
        ("Water Tap", [
            ("No hot water supply",
             "Further investigation must be made by the Developer to "
             "check on the source of problem. This problem must be "
             "rectified according to the approved method statement from "
             "the Consultant/SO."),
            ("Water tap is damaged",
             "Replace with a new water tap. Test for functionality"),
            ("Water tap is leaking/dripping",
             "Check the source of leakage. Apply Teflon tape around the "
             "pipe thread. Replace if required. Test for water leakage."),
            ("Water tap is loose",
             "Reinstall the water tap. Make sure it is tightened and "
             "firm. Test for functionality."),
            ("Water tap is rusty",
             "Replace with a new water tap. Test for functionality"),
            ("Water tap water pressure is low",
             "Further investigation must be made by the Developer to "
             "check on the source of problem. This problem must be "
             "rectified according to the approved method statement from "
             "the Consultant/SO."),
        ]),
        ("WC Cistern", [
            ("Flush button is not functioning properly",
             "Readjust the flush button installation. Test for "
             "functionality"),
            ("Toilet cistern float is not functioning. Water overflows.",
             "Replace with a new toilet cistern float. Make sure water "
             "stops at the required level. Test for functionality."),
            ("WC cistern has no water supply",
             "Further investigation must be made by the Developer to "
             "check on the source of problem. This problem must be "
             "rectified according to the approved method statement from "
             "the Consultant/SO."),
            ("WC cistern inlet pipe is rusty/damaged",
             "Replace with a new inlet pipe. Make sure the finishing is "
             "good. Test for leakage."),
            ("WC cistern is chipped/damaged",
             "Replace with a new WC cistern. Test for functionality and "
             "leakage."),
            ("WC cistern is leaking",
             "Further investigation must be made by the Developer to "
             "check on the source of problem. This problem must be "
             "rectified according to the approved method statement from "
             "the Consultant/SO."),
            ("WC cistern is loose",
             "Reinstall the cistern. Make sure it is plugged to the wall, "
             "tightened and firm. Test for functionality"),
            ("WC cistern lid is loose",
             "Reinstall the cistern lid. Replace if required. Test for "
             "functionality"),
            ("WC inlet pipe is leaking",
             "Check the source of leakage. Apply Teflon tape around the "
             "pipe thread. Replace if required. Test for water leakage."),
        ]),
        ("WC Toilet Bowl", [
            ("Gap between WC and floor tiles is not sealed off",
             "Grout the gap with sealant. Make sure the gap is fully "
             "sealed and the finishing is good."),
            ("Toilet bowl is chipped/damaged/crack",
             "Replace with a new toilet bowl. Test for functionality and "
             "leakage."),
            ("Toilet bowl is clogged/slow draining",
             "Further investigation must be made by the Developer to "
             "check on the source of problem. This problem must be "
             "rectified according to the approved method statement from "
             "the Consultant/SO."),
            ("Toilet bowl is leaking",
             "Further investigation must be made by the Developer to "
             "check on the source of problem. This problem must be "
             "rectified according to the approved method statement from "
             "the Consultant/SO."),
            ("Toilet bowl is loose",
             "Reinstall the toilet bowl. Make sure it is tightened and "
             "firm. Test for leakage and functionality."),
            ("Toilet bowl seat cover is damaged",
             "Replace with a new toilet bowl seat cover. Test for "
             "functionality."),
            ("Toilet bowl is cover is loose",
             "Reinstall the toilet bowl seat cover. Make sure it is "
             "tightened and firm. Test for functionality."),
            ("Water keeps flowing inside the toilet bowl after pressing "
             "the flush button",
             "Further investigation must be made by the Developer to "
             "check on the source of problem. This problem must be "
             "rectified according to the approved method statement from "
             "the Consultant/SO."),
        ]),
    ]),
    # Listed in the source document as main elements with no components/
    # defects populated yet — preserved as empty rather than invented.
    # A finding logged under either can never get a confident catalogue
    # match and is expected to always resolve to needs_review.
    ("Furniture", []),
    ("Others", []),
]


def slugify(text: str) -> str:
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "_", text)
    return text.strip("_")


def build_entries():
    main_elements = []
    components = []
    entries = []
    for me_index, (me_name, comp_list) in enumerate(CATALOGUE):
        me_id = slugify(me_name)
        main_elements.append({"id": me_id, "name": me_name})
        for comp_index, (comp_name, defects) in enumerate(comp_list):
            comp_id = f"{me_id}.{slugify(comp_name)}"
            components.append({
                "id": comp_id,
                "name": comp_name,
                "mainElementId": me_id,
            })
            for defect_index, (description, corrective_action) in \
                    enumerate(defects):
                defect_id = f"{comp_id}.{defect_index + 1:02d}"
                entries.append({
                    "id": defect_id,
                    "mainElementId": me_id,
                    "mainElementName": me_name,
                    "componentId": comp_id,
                    "componentName": comp_name,
                    "defectId": defect_id,
                    "defectDescription": description,
                    "correctiveAction": corrective_action,
                })
    return main_elements, components, entries


def dart_string_literal(value):
    if value is None:
        return "null"
    escaped = value.replace("\\", "\\\\").replace("'", "\\'")
    return f"'{escaped}'"


def ts_string_literal(value):
    if value is None:
        return "null"
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def generate_dart(entries) -> str:
    lines = []
    lines.append("// GENERATED FILE — do not edit by hand.")
    lines.append("//")
    lines.append("// Regenerate with: python3 tool/generate_defect_catalogue.py")
    lines.append("// Source of truth: tool/generate_defect_catalogue.py")
    lines.append("// (transcribed from \"DEFECT_REPORT_LIST.xlsx - DEFECT")
    lines.append("// LIST.pdf\").")
    lines.append("")
    lines.append("import 'defect_catalogue.dart';")
    lines.append("")
    lines.append(
        "/// All controlled defect catalogue entries — see "
        "`DefectCatalogue`"
    )
    lines.append(
        "/// (`defect_catalogue.dart`) for the queryable wrapper the rest "
        "of the"
    )
    lines.append("/// app should use instead of this raw list directly.")
    lines.append(
        "const List<DefectCatalogueEntry> kDefectCatalogueEntries = ["
    )
    for e in entries:
        lines.append("  DefectCatalogueEntry(")
        lines.append(f"    id: {dart_string_literal(e['id'])},")
        lines.append(
            f"    mainElementId: {dart_string_literal(e['mainElementId'])},"
        )
        lines.append(
            "    mainElementName: "
            f"{dart_string_literal(e['mainElementName'])},"
        )
        lines.append(
            f"    componentId: {dart_string_literal(e['componentId'])},"
        )
        lines.append(
            f"    componentName: {dart_string_literal(e['componentName'])},"
        )
        lines.append(
            f"    defectId: {dart_string_literal(e['defectId'])},"
        )
        lines.append(
            "    defectDescription: "
            f"{dart_string_literal(e['defectDescription'])},"
        )
        lines.append(
            "    correctiveAction: "
            f"{dart_string_literal(e['correctiveAction'])},"
        )
        lines.append("  ),")
    lines.append("];")
    lines.append("")
    return "\n".join(lines)


def generate_ts(entries) -> str:
    lines = []
    lines.append("// GENERATED FILE — do not edit by hand.")
    lines.append("//")
    lines.append(
        "// Regenerate with: python3 tool/generate_defect_catalogue.py"
    )
    lines.append("// Source of truth: tool/generate_defect_catalogue.py")
    lines.append("// (transcribed from \"DEFECT_REPORT_LIST.xlsx - DEFECT")
    lines.append("// LIST.pdf\").")
    lines.append("")
    lines.append('import {DefectCatalogueEntry} from "./defect_catalogue";')
    lines.append("")
    lines.append(
        "/** All controlled defect catalogue entries — see "
        "`defect_catalogue.ts`"
    )
    lines.append(
        " * for the queryable helpers the rest of the gateway should use "
        "instead"
    )
    lines.append(" * of this raw list directly. */")
    lines.append(
        "export const DEFECT_CATALOGUE_ENTRIES: DefectCatalogueEntry[] = ["
    )
    for e in entries:
        lines.append("  {")
        lines.append(f"    id: {ts_string_literal(e['id'])},")
        lines.append(
            f"    mainElementId: {ts_string_literal(e['mainElementId'])},"
        )
        lines.append(
            "    mainElementName: "
            f"{ts_string_literal(e['mainElementName'])},"
        )
        lines.append(
            f"    componentId: {ts_string_literal(e['componentId'])},"
        )
        lines.append(
            f"    componentName: {ts_string_literal(e['componentName'])},"
        )
        lines.append(f"    defectId: {ts_string_literal(e['defectId'])},")
        lines.append(
            "    defectDescription: "
            f"{ts_string_literal(e['defectDescription'])},"
        )
        lines.append(
            "    correctiveAction: "
            f"{ts_string_literal(e['correctiveAction'])},"
        )
        lines.append("  },")
    lines.append("];")
    lines.append("")
    return "\n".join(lines)


def main():
    main_elements, components, entries = build_entries()

    # Sanity checks before writing anything.
    ids = [e["id"] for e in entries]
    assert len(ids) == len(set(ids)), "duplicate defect id generated"
    comp_ids = [c["id"] for c in components]
    assert len(comp_ids) == len(set(comp_ids)), "duplicate component id"
    me_ids = [m["id"] for m in main_elements]
    assert len(me_ids) == len(set(me_ids)), "duplicate main element id"
    for e in entries:
        assert e["componentId"].startswith(e["mainElementId"] + ".")
        assert e["defectId"].startswith(e["componentId"] + ".")

    dart_out = generate_dart(entries)
    ts_out = generate_ts(entries)

    dart_path = (
        "lib/core/inspection/entities/defect_catalogue_data.dart"
    )
    ts_path = "functions/src/ai/defect_catalogue_data.ts"
    with open(dart_path, "w") as f:
        f.write(dart_out)
    with open(ts_path, "w") as f:
        f.write(ts_out)

    print(f"Main elements: {len(main_elements)}")
    print(f"Components: {len(components)}")
    print(f"Defect entries: {len(entries)}")
    print(f"Wrote {dart_path}")
    print(f"Wrote {ts_path}")


if __name__ == "__main__":
    main()
