import 'package:flutter/material.dart';

import '../../shared/study_material_screen.dart';

class ListeningScreen extends StatelessWidget {
  const ListeningScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const StudyMaterialScreen(title: 'Nghe và đọc', materialTypes: {'audio'});
}
