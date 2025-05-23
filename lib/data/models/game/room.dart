import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pif_paf_pouf/data/models/user/player.dart';

enum RoomStatus { lobby, in_game, finished }

class Room {
  final String id;
  final String joinCode;
  final String createdBy;
  final DateTime? createdAt;
  final int playerCount;
  final RoomStatus status;
  final int currentRound;
  final DateTime? roundStartTime;
  final String? winner;
  final List<String>? survivors;
  final List<Player> players;
  final String? nextRoomId;
  final String? nextRoomCode;
  final bool extendedMode;
  final DateTime? lastActivity;

  Room({
    required this.id,
    required this.joinCode,
    required this.createdBy,
    this.createdAt,
    this.playerCount = 0,
    this.status = RoomStatus.lobby,
    this.currentRound = 0,
    this.roundStartTime,
    this.winner,
    this.survivors,
    this.players = const [],
    this.nextRoomId,
    this.nextRoomCode,
    this.extendedMode = false,
    this.lastActivity,
  });

  // Factory pour créer un Room à partir d'un document Firestore
  factory Room.fromFirestore(DocumentSnapshot doc, {List<Player> players = const []}) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return Room(
      id: doc.id,
      joinCode: data['joinCode'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
      playerCount: data['playerCount'] ?? 0,
      status: _statusFromString(data['status'] ?? 'lobby'),
      currentRound: data['currentRound'] ?? 0,
      roundStartTime: data['roundStartTime'] != null ? (data['roundStartTime'] as Timestamp).toDate() : null,
      winner: data['winner'],
      survivors: data['survivors'] != null ? List<String>.from(data['survivors']) : null,
      players: players,
      nextRoomId: data['nextRoomId'],
      nextRoomCode: data['nextRoomCode'],
      extendedMode: data['extendedMode'] ?? false,
      lastActivity: data['lastActivity'] != null ? (data['lastActivity'] as Timestamp).toDate() : null,
    );
  }

  // Convertir en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'joinCode': joinCode,
      'createdBy': createdBy,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'playerCount': playerCount,
      'status': _statusToString(status),
      'currentRound': currentRound,
      'roundStartTime': roundStartTime != null ? Timestamp.fromDate(roundStartTime!) : null,
      'winner': winner,
      'survivors': survivors,
      'nextRoomId': nextRoomId,
      'nextRoomCode': nextRoomCode,
      'extendedMode': extendedMode,
      'lastActivity': lastActivity != null ? Timestamp.fromDate(lastActivity!) : FieldValue.serverTimestamp(),
    };
  }

  // Créer une copie avec des modifications
  Room copyWith({
    String? joinCode,
    String? createdBy,
    DateTime? createdAt,
    int? playerCount,
    RoomStatus? status,
    int? currentRound,
    DateTime? roundStartTime,
    String? winner,
    List<String>? survivors,
    List<Player>? players,
    String? nextRoomId,
    String? nextRoomCode,
    bool? extendedMode,
    DateTime? lastActivity,
  }) {
    return Room(
      id: id,
      joinCode: joinCode ?? this.joinCode,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      playerCount: playerCount ?? this.playerCount,
      status: status ?? this.status,
      currentRound: currentRound ?? this.currentRound,
      roundStartTime: roundStartTime ?? this.roundStartTime,
      winner: winner ?? this.winner,
      survivors: survivors ?? this.survivors,
      players: players ?? this.players,
      nextRoomId: nextRoomId ?? this.nextRoomId,
      nextRoomCode: nextRoomCode ?? this.nextRoomCode,
      extendedMode: extendedMode ?? this.extendedMode,
      lastActivity: lastActivity ?? this.lastActivity,
    );
  }

  bool get isReadyToStart {
    if (players.length < 2) return false;
    return players.every((player) => player.isReady);
  }

  // Détermine si la room est inactive depuis longtemps
  bool get isInactive {
    if (lastActivity == null) return false;
    final now = DateTime.now();
    // Considérer une room comme inactive après 2 heures
    return now.difference(lastActivity!).inHours >= 2;
  }

  static RoomStatus _statusFromString(String status) {
    switch (status) {
      case 'in_game':
        return RoomStatus.in_game;
      case 'finished':
        return RoomStatus.finished;
      case 'lobby':
      default:
        return RoomStatus.lobby;
    }
  }

  static String _statusToString(RoomStatus status) {
    switch (status) {
      case RoomStatus.in_game:
        return 'in_game';
      case RoomStatus.finished:
        return 'finished';
      case RoomStatus.lobby:
      default:
        return 'lobby';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Room &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          status == other.status &&
          currentRound == other.currentRound &&
          playerCount == other.playerCount;

  @override
  int get hashCode => id.hashCode ^ currentRound.hashCode ^ status.hashCode;
}
