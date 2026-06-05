import 'package:flutter/foundation.dart';
import 'package:rive/rive.dart';

void analyzeRiveFile(Artboard artboard) {
  debugPrint('\n==================================================');
  debugPrint('RIVE ANALYZER START: ${artboard.name}');
  debugPrint('==================================================\n');

  debugPrint('[ANIMATIONS]');
  if (artboard.animations.isEmpty) {
    debugPrint('  (no animations found)');
  } else {
    for (final animation in artboard.animations) {
      debugPrint('  - name: "${animation.name}"');
    }
  }

  debugPrint('\n[STATE MACHINES AND INPUTS]');
  if (artboard.stateMachines.isEmpty) {
    debugPrint('  (no state machines found)');
  } else {
    for (final stateMachine in artboard.stateMachines) {
      debugPrint('  - state machine: "${stateMachine.name}"');

      if (stateMachine.inputs.isEmpty) {
        debugPrint('    (no inputs)');
        continue;
      }

      for (final input in stateMachine.inputs) {
        final type = _describeInputType(input);
        debugPrint('    * input: "${input.name}" | type: $type');
      }
    }
  }

  debugPrint('\n[COMPONENT TREE]');
  debugPrint(
    '  Tip: search in console for bg, background, head, weapon, hover.',
  );

  var namedCount = 0;
  artboard.forEachComponent((component) {
    final name = component.name.trim();
    if (name.isEmpty || name == 'Unknown') {
      return;
    }

    debugPrint(
      '  - component: "${component.name}" | kind: ${component.runtimeType}',
    );
    namedCount++;
  });

  debugPrint('  Total named components: $namedCount');
  debugPrint('\n==================================================');
  debugPrint('RIVE ANALYZER END');
  debugPrint('==================================================\n');
}

String _describeInputType(dynamic input) {
  final runtime = input.runtimeType.toString().toLowerCase();

  if (runtime.contains('trigger')) {
    return 'Trigger';
  }

  if (runtime.contains('bool')) {
    return 'Boolean';
  }

  if (runtime.contains('double') || runtime.contains('number')) {
    return 'Number';
  }

  try {
    final coreType = input.coreType;
    return 'Unknown(coreType=$coreType)';
  } catch (_) {
    return input.runtimeType.toString();
  }
}
