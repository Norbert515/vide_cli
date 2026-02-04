/// Team routes for listing available team definitions.
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:vide_core/vide_core.dart';

final _log = Logger('TeamRoutes');

/// List all available teams.
Future<Response> listTeams(Request request) async {
  _log.info('GET /teams - Listing available teams');

  final loader = TeamFrameworkLoader();
  final teams = await loader.loadTeams();

  final teamsList = teams.values.map((team) => {
    'name': team.name,
    'description': team.description,
    if (team.icon != null) 'icon': team.icon,
    'main-agent': team.mainAgent,
    'agents': team.agents,
    'process': {
      'planning': team.process.planning.name,
      'review': team.process.review.name,
      'testing': team.process.testing.name,
      'documentation': team.process.documentation.name,
    },
    'communication': {
      'verbosity': team.communication.verbosity.name,
      'handoff-detail': team.communication.handoffDetail.name,
      'status-updates': team.communication.statusUpdates.name,
    },
    'triggers': team.triggers,
  }).toList();

  _log.info('Found ${teamsList.length} teams');

  return Response.ok(
    jsonEncode({'teams': teamsList}),
    headers: {'Content-Type': 'application/json'},
  );
}
