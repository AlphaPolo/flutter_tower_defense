import 'package:tower_defense/model/effects/effect_duplicate_type.dart';

const gameDebug = false;

const kThunderEffectType = IdWithEffectType(100, EffectDuplicateStrategy.last);
const kFrozenEffectType = IdWithEffectType(101, EffectDuplicateStrategy.last);
const kPoisonEffectType = IdWithEffectType(102, EffectDuplicateStrategy.last);
const kBurnEffectType = IdWithEffectType(103, EffectDuplicateStrategy.last);
const kVulnerableEffectType =
    IdWithEffectType(104, EffectDuplicateStrategy.last);
const kBleedEffectType = IdWithEffectType(105, EffectDuplicateStrategy.last);