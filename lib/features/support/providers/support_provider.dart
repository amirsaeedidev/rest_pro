import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/model/support_model.dart';
import '../../../core/services/supabase_service.dart';

class SupportProvider extends ChangeNotifier {
  List<TicketModel> _tickets = const [];
  bool _isLoadingTickets = false;
  List<TicketMessageModel> _messages = const [];
  bool _isLoadingMessages = false;
  bool _disposed = false;
  String? _activeUserId;
  String? _activeTicketId;
  int _ticketFetchGeneration = 0;
  int _messageFetchGeneration = 0;
  StreamSubscription<List<Map<String, dynamic>>>? _ticketsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _messagesSubscription;

  List<TicketModel> get tickets => List.unmodifiable(_tickets);
  bool get isLoadingTickets => _isLoadingTickets;
  List<TicketMessageModel> get messages => List.unmodifiable(_messages);
  bool get isLoadingMessages => _isLoadingMessages;

  Future<void> fetchTickets() async {
    if (_disposed) return;
    final generation = ++_ticketFetchGeneration;
    _isLoadingTickets = true;
    notifyListeners();

    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        _tickets = const [];
        _activeUserId = null;
        await _ticketsSubscription?.cancel();
        _ticketsSubscription = null;
        return;
      }

      final response = await SupabaseService.client
          .from('tickets')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false);
      if (generation != _ticketFetchGeneration || _disposed) return;

      _tickets = (response as List)
          .map((row) => TicketModel.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false);
      _activeUserId = userId;
      _subscribeToTickets(userId);
    } catch (error) {
      debugPrint('Fetch support tickets failed: $error');
    } finally {
      if (generation == _ticketFetchGeneration && !_disposed) {
        _isLoadingTickets = false;
        notifyListeners();
      }
    }
  }

  void _subscribeToTickets(String userId) {
    if (_disposed ||
        (_activeUserId == userId && _ticketsSubscription != null)) {
      return;
    }
    _activeUserId = userId;
    _ticketsSubscription?.cancel();
    _ticketsSubscription = SupabaseService.client
        .from('tickets')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('updated_at', ascending: false)
        .listen(
      (rows) {
        if (_disposed || _activeUserId != userId) return;
        _tickets = rows.map(TicketModel.fromJson).toList(growable: false);
        notifyListeners();
      },
      onError: (Object error) => debugPrint('Tickets realtime error: $error'),
    );
  }

  Future<bool> createTicket(String subject, String message, String? orderId) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return false;

      final ticketResponse = await SupabaseService.client
          .from('tickets')
          .insert({'user_id': userId, 'subject': subject.trim()})
          .select()
          .single();
      final ticket = TicketModel.fromJson(Map<String, dynamic>.from(ticketResponse));

      var fullMessage = message.trim();
      if (orderId != null && orderId.trim().isNotEmpty) {
        fullMessage = 'شماره سفارش: ${orderId.trim()}\n\n$fullMessage';
      }
      await SupabaseService.client.from('ticket_messages').insert({
        'ticket_id': ticket.id,
        'user_id': userId,
        'message': fullMessage,
        'is_admin': false,
      });

      if (!_tickets.any((item) => item.id == ticket.id)) {
        _tickets = [ticket, ..._tickets];
      }
      _activeUserId = userId;
      _subscribeToTickets(userId);
      notifyListeners();
      return true;
    } catch (error) {
      debugPrint('Create support ticket failed: $error');
      return false;
    }
  }

  Future<void> fetchMessages(String ticketId) async {
    if (_disposed) return;
    final generation = ++_messageFetchGeneration;
    _isLoadingMessages = true;
    _messages = const [];
    _activeTicketId = ticketId;
    notifyListeners();

    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return;
      final response = await SupabaseService.client
          .from('ticket_messages')
          .select()
          .eq('ticket_id', ticketId)
          .order('created_at', ascending: true);
      if (generation != _messageFetchGeneration || _disposed) return;

      _messages = (response as List)
          .map((row) => TicketMessageModel.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false);
      _subscribeToMessages(ticketId);
    } catch (error) {
      debugPrint('Fetch ticket messages failed: $error');
    } finally {
      if (generation == _messageFetchGeneration && !_disposed) {
        _isLoadingMessages = false;
        notifyListeners();
      }
    }
  }

  void _subscribeToMessages(String ticketId) {
    if (_disposed ||
        (_activeTicketId == ticketId && _messagesSubscription != null)) {
      return;
    }
    _activeTicketId = ticketId;
    _messagesSubscription?.cancel();
    _messagesSubscription = SupabaseService.client
        .from('ticket_messages')
        .stream(primaryKey: ['id'])
        .eq('ticket_id', ticketId)
        .order('created_at')
        .listen(
      (rows) {
        if (_disposed || _activeTicketId != ticketId) return;
        _messages = rows.map(TicketMessageModel.fromJson).toList(growable: false);
        notifyListeners();
      },
      onError: (Object error) => debugPrint('Ticket messages realtime error: $error'),
    );
  }

  Future<void> sendMessage(String ticketId, String text) async {
    final message = text.trim();
    if (message.isEmpty) return;

    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return;
      final response = await SupabaseService.client
          .from('ticket_messages')
          .insert({
            'ticket_id': ticketId,
            'user_id': userId,
            'message': message,
            'is_admin': false,
          })
          .select()
          .single();
      final saved = TicketMessageModel.fromJson(Map<String, dynamic>.from(response));
      if (!_messages.any((item) => item.id == saved.id)) {
        _messages = [..._messages, saved];
      }

      await SupabaseService.client
          .from('tickets')
          .update({'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', ticketId)
          .eq('user_id', userId);
      notifyListeners();
    } catch (error) {
      debugPrint('Send ticket message failed: $error');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ticketFetchGeneration++;
    _messageFetchGeneration++;
    _ticketsSubscription?.cancel();
    _messagesSubscription?.cancel();
    super.dispose();
  }
}
