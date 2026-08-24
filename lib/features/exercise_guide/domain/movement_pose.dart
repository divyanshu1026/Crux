/// A side-on stick figure posed by joint angles, and the movement patterns the
/// exercise library maps onto.
///
/// Why angles rather than stored artwork: there are ~100 exercises in the app
/// but only a handful of *patterns*. A back squat and a goblet squat are the
/// same movement with the load somewhere else, so one squat pose pair covers
/// both. That turns "commission 100 animations" into "describe 8 movements",
/// which is something the app can carry in a few kilobytes and render at any
/// size, in either theme, offline.
///
/// Angles are degrees measured clockwise from straight up, for a figure facing
/// right: 0 points up, 90 points forward, -90 points back, 180 points down.
/// Every segment is drawn from its parent joint outward, so limbs stay rigid
/// no matter how two poses are blended.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset;

class Pose {
  const Pose({
    required this.shin,
    required this.thigh,
    required this.torso,
    required this.upperArm,
    required this.foreArm,
    this.hipShift = 0,
    this.heelLift = 0,
    this.armsFollowTorso = false,
  });

  final double shin; // ankle → knee
  final double thigh; // knee → hip
  final double torso; // hip → shoulder
  final double upperArm; // shoulder → elbow
  final double foreArm; // elbow → hand

  /// Horizontal drift of the whole body, in shin-lengths. Lets a pose move the
  /// mass over the midfoot instead of pivoting rigidly around the ankle.
  final double hipShift;

  /// How far the heel comes off the floor, in shin-lengths. Only used by
  /// deliberately-wrong poses — a lifted heel is a mistake, not a technique.
  final double heelLift;

  /// Whether the arm angles are measured from the spine rather than from
  /// vertical.
  ///
  /// It depends on what the hands are doing. Hands gripping a bar on your
  /// back travel with your torso, so they must rotate with it — leaving them
  /// absolute made the arms swing across the chest into an X as soon as the
  /// figure leaned. Hands holding a hanging barbell do the opposite: gravity
  /// keeps them vertical no matter what the spine does.
  final bool armsFollowTorso;

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  Pose lerpTo(Pose other, double t) => Pose(
        shin: _lerp(shin, other.shin, t),
        thigh: _lerp(thigh, other.thigh, t),
        torso: _lerp(torso, other.torso, t),
        upperArm: _lerp(upperArm, other.upperArm, t),
        foreArm: _lerp(foreArm, other.foreArm, t),
        hipShift: _lerp(hipShift, other.hipShift, t),
        heelLift: _lerp(heelLift, other.heelLift, t),
        armsFollowTorso: armsFollowTorso,
      );
}

/// Segment lengths relative to the shin, roughly average adult proportions.
class _Limb {
  static const shin = 1.0;
  static const thigh = 1.0;
  static const torso = 1.25;
  static const upperArm = 0.72;
  static const foreArm = 0.68;
  static const neck = 0.18;
  static const headRadius = 0.26;
  static const foot = 0.42;
}

/// Joint positions in figure space: +x forward (the way the figure faces),
/// +y up, origin at the ankle. Callers map this to canvas coordinates.
class Skeleton {
  const Skeleton({
    required this.ankle,
    required this.knee,
    required this.hip,
    required this.shoulder,
    required this.elbow,
    required this.hand,
    required this.head,
    required this.toe,
    required this.heel,
  });

  final Offset ankle;
  final Offset knee;
  final Offset hip;
  final Offset shoulder;
  final Offset elbow;
  final Offset hand;
  final Offset head;
  final Offset toe;
  final Offset heel;

  /// Forward kinematics: walk the chain from the ankle up, so each segment
  /// keeps its exact length and only its direction changes.
  factory Skeleton.fromPose(Pose pose) {
    Offset step(Offset from, double degrees, double length) {
      final r = degrees * math.pi / 180.0;
      return Offset(
        from.dx + math.sin(r) * length,
        from.dy + math.cos(r) * length,
      );
    }

    final ankle = Offset(pose.hipShift, pose.heelLift);
    final knee = step(ankle, pose.shin, _Limb.shin);
    final hip = step(knee, pose.thigh, _Limb.thigh);
    final shoulder = step(hip, pose.torso, _Limb.torso);
    final armBase = pose.armsFollowTorso ? pose.torso : 0.0;
    final elbow = step(shoulder, armBase + pose.upperArm, _Limb.upperArm);
    final hand = step(elbow, armBase + pose.foreArm, _Limb.foreArm);
    // The head sits on the end of the torso line, so gaze follows the spine.
    final head = step(shoulder, pose.torso, _Limb.neck + _Limb.headRadius);

    // The foot stays flat on the floor unless the pose lifts the heel, in
    // which case it pivots at the toe — which is exactly what it looks like
    // when someone's heels come up out of a squat.
    final toe = Offset(ankle.dx + _Limb.foot * 0.62, 0);
    final heel = Offset(ankle.dx - _Limb.foot * 0.38, pose.heelLift);

    return Skeleton(
      ankle: ankle,
      knee: knee,
      hip: hip,
      shoulder: shoulder,
      elbow: elbow,
      hand: hand,
      head: head,
      toe: toe,
      heel: heel,
    );
  }

  static double get headRadius => _Limb.headRadius;

  /// Bounding box of every joint, used to fit the figure to its box.
  (double minX, double maxX, double minY, double maxY) bounds() {
    final pts = [ankle, knee, hip, shoulder, elbow, hand, head, toe, heel];
    var minX = pts.first.dx, maxX = pts.first.dx;
    var minY = pts.first.dy, maxY = pts.first.dy;
    for (final p in pts) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    return (
      minX - _Limb.headRadius,
      maxX + _Limb.headRadius,
      minY,
      maxY + _Limb.headRadius,
    );
  }
}

/// Where the load sits, so the drawing shows a bar rather than an empty hand.
enum LoadStyle { none, barbellBack, barbellHands, dumbbellChest, dumbbellHands }

/// One demonstrable movement, as a pair of poses plus the labels for each end.
class MovementPattern {
  const MovementPattern({
    required this.id,
    required this.name,
    required this.top,
    required this.bottom,
    required this.topLabel,
    required this.bottomLabel,
    required this.load,
    this.watchFor,
  });

  final String id;
  final String name;
  final Pose top;
  final Pose bottom;
  final String topLabel;
  final String bottomLabel;
  final LoadStyle load;

  /// The single most common way this movement goes wrong, drawn as a ghost
  /// behind the correct figure. Seeing the error next to the fix is the part a
  /// photo can't do — you can't photograph "your back is rounding" clearly, but
  /// you can draw it.
  final ({String label, Pose pose})? watchFor;

  Pose at(double t) => top.lerpTo(bottom, t);
}

abstract final class MovementPatterns {
  /// Squat — knees and hips bend together, torso stays as upright as the
  /// load allows.
  static const squat = MovementPattern(
    id: 'squat',
    name: 'Squat',
    load: LoadStyle.barbellBack,
    topLabel: 'Stand tall',
    bottomLabel: 'Hips below knees',
    // Arms are pinned back and up throughout: that is a bar held on the back,
    // and it stops the figure reading as someone reaching forward.
    top: Pose(
      shin: 4,
      thigh: -2,
      torso: 4,
      upperArm: -150,
      foreArm: -20,
      armsFollowTorso: true,
    ),
    bottom: Pose(
      shin: 38,
      thigh: -104,
      // Only 24 degrees of lean. The hips travel a long way back, so the
      // torso has to stay upright to keep the bar stacked over the midfoot —
      // solved for rather than eyeballed.
      torso: 24,
      upperArm: -150,
      foreArm: -20,
      hipShift: -0.10,
      armsFollowTorso: true,
    ),
    watchFor: (
      // The classic squat fault: the hips rise faster than the chest, so it
      // turns into a good morning. Drawn shallower than the correct pose on
      // purpose — at full depth the torso line crosses back over the thigh
      // and the figure stops reading as a person.
      label: 'Hips shoot up, chest drops — it becomes a good morning',
      pose: Pose(
        shin: 40,
        thigh: -75,
        torso: 58,
        upperArm: -150,
        foreArm: -20,
        hipShift: -0.10,
        armsFollowTorso: true,
      ),
    ),
  );

  /// Hinge — the hips travel back, the knees barely move. This is the pattern
  /// people most often turn into a bad squat, which is why it gets a ghost.
  static const hinge = MovementPattern(
    id: 'hinge',
    name: 'Hip hinge (deadlift / RDL)',
    load: LoadStyle.barbellHands,
    topLabel: 'Locked out',
    bottomLabel: 'Hips back, back flat',
    top: Pose(shin: 4, thigh: -2, torso: 3, upperArm: 178, foreArm: 179),
    bottom: Pose(
      shin: 10,
      thigh: -14,
      torso: 74,
      upperArm: 178,
      foreArm: 179,
      hipShift: -0.3,
    ),
    watchFor: (
      label: 'Squatting it — knees forward, back rounded',
      pose: Pose(
        shin: 34,
        thigh: -62,
        torso: 78,
        upperArm: 178,
        foreArm: 179,
        hipShift: 0.1,
      ),
    ),
  );

  static const all = [squat, hinge];

  /// Maps an exercise name onto a pattern. Returns null when nothing matches,
  /// so the guide sheet simply omits the diagram rather than showing a squat
  /// for a bicep curl.
  static MovementPattern? forExercise(String exerciseName) {
    final n = exerciseName.toLowerCase();
    const hingeKeys = [
      'deadlift',
      'romanian',
      'rdl',
      'good morning',
      'hip thrust',
      'glute bridge',
      'back extension',
    ];
    const squatKeys = [
      'squat',
      'lunge',
      'split squat',
      'step-up',
      'step up',
      'leg press',
    ];
    if (hingeKeys.any(n.contains)) return hinge;
    if (squatKeys.any(n.contains)) return squat;
    return null;
  }
}
