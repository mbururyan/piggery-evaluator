import 'package:flutter/material.dart';

import '../../constants/visit_template.dart';
import '../../models/visit.dart';
import '../../utils/snackbars.dart';
import '../review_submit_screen.dart';
import 'breeding_section_screen.dart';
import 'checklist_section_screen.dart';
import 'close_out_section_screen.dart';
import 'intake_section_screen.dart';
import 'population_section_screen.dart';
import 'production_section_screen.dart';

/// Opens the right screen for a section. One place for this, so the hub
/// and every "Save & next" button route the same way.
///
/// [replace] = true when moving section to section, so Back always lands
/// on the hub instead of walking back through every section visited.
void openSection(BuildContext context, Visit visit, VisitSection s,
    {bool replace = false}) {
  final Widget screen = switch (s) {
    VisitSection.production => ProductionSectionScreen(visit: visit),
    VisitSection.breeding => BreedingSectionScreen(visit: visit),
    VisitSection.population => PopulationSectionScreen(visit: visit),
    VisitSection.intake => IntakeSectionScreen(visit: visit),
    VisitSection.closeOut => CloseOutSectionScreen(visit: visit),
    _ => ChecklistSectionScreen(
        visit: visit, template: VisitTemplates.checklistFor(s)!),
  };

  final route = MaterialPageRoute(builder: (_) => screen);
  replace
      ? Navigator.of(context).pushReplacement(route)
      : Navigator.of(context).push(route);
}

/// After saving a section: go to the next one. After the last: straight
/// to Review & submit if everything's done, otherwise back to the hub
/// with how many are left.
void openNextSection(BuildContext context, Visit visit, VisitSection current) {
  final i = VisitSection.values.indexOf(current);
  if (i == VisitSection.values.length - 1) {
    if (visit.isDraft && visit.canSubmit) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => ReviewSubmitScreen(visitId: visit.id)));
      return;
    }
    Navigator.of(context).pop();
    final left = VisitSection.values.length - visit.doneCount;
    if (visit.isDraft && left > 0) {
      showInfoSnack(context, '$left ${left == 1 ? 'section' : 'sections'} still to finish');
    }
    return;
  }
  openSection(context, visit, VisitSection.values[i + 1], replace: true);
}