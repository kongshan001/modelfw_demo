class_name BattleTypes
extends RefCounted

enum Side { ALLY, ENEMY }
enum IntentKind { ATTACK, SKILL, ITEM, DEFEND, FLEE }
enum DamageType { PHYSICAL, MAGIC, HEAL, NONE }
enum Outcome { NONE, VICTORY, DEFEAT, ESCAPED }
