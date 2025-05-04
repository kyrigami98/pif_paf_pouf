import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pif_paf_pouf/models/player.dart';

enum RoomStatus { waiting, ready, playing, completed }

class Room {
  final String id;
  final String roomCode;
  final String createdBy;
  final DateTime? createdAt;
  final int playerCount;
  final RoomStatus status;
  final bool gameStarted;
  final int currentRound;
  final DateTime? roundStartTime;
  final String? winner;
  final List<String>? survivors;
  final List<Player> players;

  Room({
    required this.id,
    required this.roomCode,
    required this.createdBy,
    this.createdAt,
    this.playerCount = 0,
    this.status = RoomStatus.waiting,
    this.gameStarted = false,
    this.currentRound = 0,
    this.roundStartTime,
    this.winner,
    this.survivors,
    this.players = const [],
  });

  // Factory pour créer un Room à partir d'un document Firestore
  factory Room.fromFirestore(DocumentSnapshot doc, {List<Player> players = const []}) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return Room(
      id: doc.id,
      roomCode: data['roomCode'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
      playerCount: data['playerCount'] ?? 0,
      status: _statusFromString(data['status'] ?? 'waiting'),
      gameStarted: data['gameStarted'] ?? false,
      currentRound: data['currentRound'] ?? 0,
      roundStartTime: data['roundStartTime'] != null ? (data['roundStartTime'] as Timestamp).toDate() : null,
      winner: data['winner'],
      survivors: data['survivors'] != null ? List<String>.from(data['survivors']) : null,
      players: players,
    );
  }

  // Convertir en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'roomCode': roomCode,
      'createdBy': createdBy,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'playerCount': playerCount,
      'status': _statusToString(status),
      'gameStarted': gameStarted,
      'currentRound': currentRound,
      'roundStartTime': roundStartTime != null ? Timestamp.fromDate(roundStartTime!) : null,
      'winner': winner,
      'survivors': survivors,
    };
  }

  // Créer une copie avec des modifications
  Room copyWith({
    String? roomCode,
    String? createdBy,
    DateTime? createdAt,
    int? playerCount,
    RoomStatus? status,
    bool? gameStarted,
    int? currentRound,
    DateTime? roundStartTime,
    String? winner,
    List<String>? survivors,
    List<Player>? players,
  }) {
    return Room(
      id: this.id,
      roomCode: roomCode ?? this.roomCode,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      playerCount: playerCount ?? this.playerCount,
      status: status ?? this.status,
      gameStarted: gameStarted ?? this.gameStarted,
      currentRound: currentRound ?? this.currentRound,
      roundStartTime: roundStartTime ?? this.roundStartTime,
      winner: winner ?? this.winner,
      survivors: survivors ?? this.survivors,
      players: players ?? this.players,
    );
  }

  bool get isReadyToStart {
    if (players.length < 2) return false;
    return players.every((player) => player.isReady);
  }

  static RoomStatus _statusFromString(String status) {
    switch (status) {
      case 'ready':
        return RoomStatus.ready;
      case 'playing':
        return RoomStatus.playing;
      case 'completed':
        return RoomStatus.completed;
      case 'waiting':
      default:
        return RoomStatus.waiting;
    }
  }

  static String _statusToString(RoomStatus status) {
    switch (status) {
      case RoomStatus.ready:
        return 'ready';
      case RoomStatus.playing:
        return 'playing';
      case RoomStatus.completed:
        return 'completed';
      case RoomStatus.waiting:
      default:
        return 'waiting';
    }
  }
}
