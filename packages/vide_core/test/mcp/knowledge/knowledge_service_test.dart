import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;
import 'package:vide_core/src/mcp/knowledge/knowledge_service.dart';

void main() {
  group('KnowledgeService', () {
    late Directory tempDir;
    late KnowledgeService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('knowledge_test_');
      service = KnowledgeService(projectPath: tempDir.path);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    group('ensureDirectoryStructure', () {
      test('creates knowledge directories', () async {
        await service.ensureDirectoryStructure();

        expect(
          await Directory(
            path.join(service.knowledgeRoot, 'global', 'decisions'),
          ).exists(),
          isTrue,
        );
        expect(
          await Directory(
            path.join(service.knowledgeRoot, 'global', 'patterns'),
          ).exists(),
          isTrue,
        );
        expect(
          await Directory(
            path.join(service.knowledgeRoot, 'global', 'findings'),
          ).exists(),
          isTrue,
        );
      });
    });

    group('writeDocument', () {
      test('creates document with frontmatter', () async {
        await service.ensureDirectoryStructure();
        await service.writeDocument(
          docPath: 'global/decisions/test-decision.md',
          title: 'Test Decision',
          type: 'decision',
          content: 'This is the decision content.',
          tags: ['test', 'example'],
          author: 'TestAgent',
        );

        final file = File(
          path.join(service.knowledgeRoot, 'global/decisions/test-decision.md'),
        );
        expect(await file.exists(), isTrue);

        final content = await file.readAsString();
        expect(content, contains('title: Test Decision'));
        expect(content, contains('type: decision'));
        expect(content, contains('status: active'));
        expect(content, contains('author: TestAgent'));
        expect(content, contains('tags: [test, example]'));
        expect(content, contains('# Test Decision'));
        expect(content, contains('This is the decision content.'));
      });

      test('creates nested directories if needed', () async {
        await service.writeDocument(
          docPath: 'teams/auth-team/findings/token-format.md',
          title: 'Token Format',
          type: 'finding',
          content: 'JWT tokens use...',
        );

        final file = File(
          path.join(
            service.knowledgeRoot,
            'teams/auth-team/findings/token-format.md',
          ),
        );
        expect(await file.exists(), isTrue);
      });
    });

    group('readDocument', () {
      test('reads document with full content', () async {
        await service.ensureDirectoryStructure();
        await service.writeDocument(
          docPath: 'global/findings/test.md',
          title: 'Test Finding',
          type: 'finding',
          content:
              'First paragraph of the finding.\n\nSecond paragraph with more details.',
          tags: ['test'],
        );

        final doc = await service.readDocument('global/findings/test.md');

        expect(doc, isNotNull);
        expect(doc!.title, equals('Test Finding'));
        expect(doc.type, equals('finding'));
        expect(doc.status, equals('active'));
        expect(doc.tags, contains('test'));
        expect(doc.content, isNotNull);
        expect(doc.content, contains('First paragraph'));
        expect(doc.content, contains('Second paragraph'));
      });

      test('returns null for non-existent document', () async {
        final doc = await service.readDocument('nonexistent.md');
        expect(doc, isNull);
      });
    });

    group('getSummary', () {
      test('returns document with summary but no full content', () async {
        await service.ensureDirectoryStructure();
        await service.writeDocument(
          docPath: 'global/decisions/summary-test.md',
          title: 'Summary Test',
          type: 'decision',
          content:
              'This is the first paragraph summary.\n\nThis is the second paragraph.',
        );

        final doc = await service.getSummary(
          'global/decisions/summary-test.md',
        );

        expect(doc, isNotNull);
        expect(doc!.title, equals('Summary Test'));
        expect(doc.summary, isNotNull);
        expect(doc.summary, contains('first paragraph'));
        expect(doc.content, isNull); // Full content not included
      });
    });

    group('getIndex', () {
      test('returns list of documents with metadata only', () async {
        await service.ensureDirectoryStructure();
        await service.writeDocument(
          docPath: 'global/decisions/decision1.md',
          title: 'Decision 1',
          type: 'decision',
          content: 'Content 1',
        );
        await service.writeDocument(
          docPath: 'global/findings/finding1.md',
          title: 'Finding 1',
          type: 'finding',
          content: 'Content 2',
        );

        final documents = await service.getIndex();

        expect(documents, hasLength(2));
        expect(
          documents.map((d) => d.title),
          containsAll(['Decision 1', 'Finding 1']),
        );
        // Should not have content in shallow query
        for (final doc in documents) {
          expect(doc.content, isNull);
        }
      });

      test('filters by scope', () async {
        await service.ensureDirectoryStructure();
        await service.writeDocument(
          docPath: 'global/decisions/global-doc.md',
          title: 'Global Doc',
          type: 'decision',
          content: 'Global content',
        );
        await service.writeDocument(
          docPath: 'teams/auth/findings/team-doc.md',
          title: 'Team Doc',
          type: 'finding',
          content: 'Team content',
        );

        final globalDocs = await service.getIndex(scope: 'global');
        expect(globalDocs, hasLength(1));
        expect(globalDocs.first.title, equals('Global Doc'));

        final teamDocs = await service.getIndex(scope: 'team:auth');
        expect(teamDocs, hasLength(1));
        expect(teamDocs.first.title, equals('Team Doc'));
      });
    });

    group('listDocuments', () {
      test('filters by type', () async {
        await service.ensureDirectoryStructure();
        await service.writeDocument(
          docPath: 'global/decisions/d1.md',
          title: 'Decision',
          type: 'decision',
          content: 'Decision content',
        );
        await service.writeDocument(
          docPath: 'global/findings/f1.md',
          title: 'Finding',
          type: 'finding',
          content: 'Finding content',
        );

        final decisions = await service.listDocuments(type: 'decision');
        expect(decisions, hasLength(1));
        expect(decisions.first.type, equals('decision'));

        final findings = await service.listDocuments(type: 'finding');
        expect(findings, hasLength(1));
        expect(findings.first.type, equals('finding'));
      });

      test('filters by tags', () async {
        await service.ensureDirectoryStructure();
        await service.writeDocument(
          docPath: 'global/decisions/tagged.md',
          title: 'Tagged Doc',
          type: 'decision',
          content: 'Content',
          tags: ['auth', 'security'],
        );
        await service.writeDocument(
          docPath: 'global/decisions/untagged.md',
          title: 'Untagged Doc',
          type: 'decision',
          content: 'Content',
        );

        final authDocs = await service.listDocuments(tags: ['auth']);
        expect(authDocs, hasLength(1));
        expect(authDocs.first.title, equals('Tagged Doc'));
      });
    });

    group('searchDocuments', () {
      test('finds documents by keyword in content', () async {
        await service.ensureDirectoryStructure();
        await service.writeDocument(
          docPath: 'global/decisions/jwt.md',
          title: 'JWT Authentication',
          type: 'decision',
          content: 'We use JWT tokens for stateless authentication.',
          tags: ['auth'],
        );
        await service.writeDocument(
          docPath: 'global/decisions/other.md',
          title: 'Other Decision',
          type: 'decision',
          content: 'Something unrelated.',
        );

        final results = await service.searchDocuments('authentication');
        expect(results, hasLength(1));
        expect(results.first.document.title, equals('JWT Authentication'));
        expect(results.first.score, greaterThan(0));
      });

      test('ranks title matches higher', () async {
        await service.ensureDirectoryStructure();
        await service.writeDocument(
          docPath: 'global/findings/title-match.md',
          title: 'JWT Tokens Overview',
          type: 'finding',
          content: 'General overview.',
        );
        await service.writeDocument(
          docPath: 'global/findings/content-match.md',
          title: 'Authentication Guide',
          type: 'finding',
          content: 'We use JWT tokens here.',
        );

        final results = await service.searchDocuments('JWT');
        expect(results, hasLength(2));
        // Title match should score higher
        expect(results.first.document.title, equals('JWT Tokens Overview'));
      });

      test('respects limit parameter', () async {
        await service.ensureDirectoryStructure();
        for (var i = 0; i < 5; i++) {
          await service.writeDocument(
            docPath: 'global/findings/doc$i.md',
            title: 'Test Document $i',
            type: 'finding',
            content: 'Contains the search keyword.',
          );
        }

        final results = await service.searchDocuments('search', limit: 3);
        expect(results, hasLength(3));
      });
    });
  });
}
