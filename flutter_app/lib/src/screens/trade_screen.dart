import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/trade_offer.dart';
import '../services/trade_service.dart';
import '../state/game_state.dart';
import '../widgets/glass_panel.dart';

class TradeScreen extends StatefulWidget {
  const TradeScreen({super.key});

  @override
  State<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends State<TradeScreen> {
  final _svc = TradeService();
  final _targetCtrl = TextEditingController();
  final _offerCashCtrl = TextEditingController();
  final _requestCashCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _targetCtrl.dispose();
    _offerCashCtrl.dispose();
    _requestCashCtrl.dispose();
    super.dispose();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _sendOffer(GameState state) async {
    final toId = _targetCtrl.text.trim();
    if (toId.isEmpty || toId == state.userId) {
      _snack(state.tt(
        'Gecerli bir oyuncu ID gir.',
        'Enter a valid player ID.',
      ));
      return;
    }

    final offerCash = int.tryParse(_offerCashCtrl.text.trim()) ?? 0;
    final requestCash = int.tryParse(_requestCashCtrl.text.trim()) ?? 0;

    if (offerCash <= 0 && requestCash <= 0) {
      _snack(state.tt(
        'En az bir miktar belirt.',
        'Specify at least one amount.',
      ));
      return;
    }
    if (offerCash > state.cash) {
      _snack(state.tt('Yeterli nakitin yok.', 'Not enough cash.'));
      return;
    }

    setState(() => _sending = true);
    try {
      await _svc.createOffer(
        fromId: state.userId,
        fromName: state.displayPlayerName,
        toId: toId,
        toName: '',
        offerCash: offerCash,
        requestCash: requestCash,
      );
      _snack(state.tt('Teklif gonderildi!', 'Offer sent!'));
      _targetCtrl.clear();
      _offerCashCtrl.clear();
      _requestCashCtrl.clear();
    } catch (e) {
      _snack(state.tt('Teklif gonderilemedi.', 'Failed to send offer.'));
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _respond(
    GameState state,
    TradeOffer offer,
    String action,
  ) async {
    try {
      await _svc.respondToOffer(offerId: offer.id, action: action);
      _snack(action == 'accept'
          ? state.tt('Takas kabul edildi!', 'Trade accepted!')
          : state.tt('Takas reddedildi.', 'Trade rejected.'));
    } catch (e) {
      _snack(state.tt('Islem basarisiz.', 'Operation failed.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, state, _) {
        if (state.authMode != 'firebase' || state.userId.isEmpty) {
          return Scaffold(
            backgroundColor: const Color(0xFF081428),
            appBar: AppBar(
              backgroundColor: Colors.black,
              title: Text(
                state.tt('TAKAS', 'TRADE'),
                style: const TextStyle(
                  color: Color(0xFFFBBF24),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            body: Center(
              child: Text(
                state.tt(
                  'Takas icin giris yapman gerekiyor.',
                  'You need to be logged in to trade.',
                ),
                style: const TextStyle(color: Colors.white54),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFF081428),
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(
              state.tt('TAKAS', 'TRADE'),
              style: const TextStyle(
                color: Color(0xFFFBBF24),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            children: [
              // Create offer
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.tt('YENI TEKLIF', 'NEW OFFER'),
                      style: const TextStyle(
                        color: Color(0xFFFBBF24),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _targetCtrl,
                      decoration: InputDecoration(
                        labelText: state.tt(
                          'Hedef Oyuncu ID',
                          'Target Player ID',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _offerCashCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: state.tt(
                                'Sen verecegin \$',
                                'You offer \$',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _requestCashCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: state.tt(
                                'Istedigin \$',
                                'You request \$',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _sending ? null : () => _sendOffer(state),
                        child: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : Text(state.tt(
                                'Teklif Gonder',
                                'Send Offer',
                              )),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Incoming offers
              Text(
                state.tt('GELEN TEKLIFLER', 'INCOMING OFFERS'),
                style: const TextStyle(
                  color: Color(0xFFFBBF24),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<TradeOffer>>(
                stream: _svc.watchIncoming(state.userId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final offers = snap.data ?? [];
                  if (offers.isEmpty) {
                    return GlassPanel(
                      child: Text(
                        state.tt(
                          'Gelen teklif yok.',
                          'No incoming offers.',
                        ),
                        style: const TextStyle(color: Colors.white38),
                      ),
                    );
                  }
                  return Column(
                    children: offers.map((o) => _offerCard(state, o, true)).toList(),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Outgoing offers
              Text(
                state.tt('GONDERILEN TEKLIFLER', 'OUTGOING OFFERS'),
                style: const TextStyle(
                  color: Color(0xFFFBBF24),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<TradeOffer>>(
                stream: _svc.watchOutgoing(state.userId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final offers = snap.data ?? [];
                  if (offers.isEmpty) {
                    return GlassPanel(
                      child: Text(
                        state.tt(
                          'Gonderilen teklif yok.',
                          'No outgoing offers.',
                        ),
                        style: const TextStyle(color: Colors.white38),
                      ),
                    );
                  }
                  return Column(
                    children: offers.map((o) => _offerCard(state, o, false)).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _offerCard(GameState state, TradeOffer offer, bool isIncoming) {
    return GlassPanel(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_horiz, color: Color(0xFFFBBF24), size: 20),
              const SizedBox(width: 8),
              Text(
                isIncoming
                    ? (offer.fromName.isNotEmpty ? offer.fromName : offer.fromId.substring(0, 8))
                    : state.tt('Hedef: ', 'To: ') + offer.toId.substring(0, 8),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (offer.offerCash > 0)
            Text(
              '${state.tt('Teklif', 'Offers')}: \$${offer.offerCash}',
              style: const TextStyle(color: Color(0xFF34D399)),
            ),
          if (offer.requestCash > 0)
            Text(
              '${state.tt('Istiyor', 'Wants')}: \$${offer.requestCash}',
              style: const TextStyle(color: Color(0xFFEF4444)),
            ),
          if (isIncoming) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => _respond(state, offer, 'accept'),
                    child: Text(state.tt('Kabul', 'Accept')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _respond(state, offer, 'reject'),
                    child: Text(state.tt('Reddet', 'Reject')),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: () async {
                await _svc.cancelOffer(offer.id);
                _snack(state.tt('Teklif iptal edildi.', 'Offer cancelled.'));
              },
              child: Text(
                state.tt('Iptal Et', 'Cancel'),
                style: const TextStyle(color: Color(0xFFEF4444)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
