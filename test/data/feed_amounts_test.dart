import 'package:baby_app2/data/amount_text.dart';
import 'package:baby_app2/data/feed_amounts.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_sync.dart';

void main() {
  late FakeSettingsStore settings;
  late FeedAmounts amounts;

  Future<FeedAmounts> reopened() async {
    final next = FeedAmounts(settings);
    await next.load();
    return next;
  }

  setUp(() {
    settings = FakeSettingsStore();
    amounts = FeedAmounts(settings);
  });

  test('parseAmount accepts a comma as the decimal point', () {
    expect(parseAmount(' 62,5 '), 62.5);
    expect(parseAmount('120'), 120);
    expect(parseAmount('abc'), isNull);
    expect(parseAmount(''), isNull);
  });

  test('formatAmount drops a needless .0', () {
    expect(formatAmount(120), '120');
    expect(formatAmount(62.5), '62.5');
  });

  test('a new phone has the premade amounts and a default', () async {
    await amounts.load();

    expect(amounts.values, FeedAmounts.premade);
    expect(FeedAmounts.premade, contains(amounts.defaultAmount));
  });

  test('added amounts are kept in order and remembered', () async {
    expect(await amounts.add(75), isTrue);

    expect((await reopened()).values, [60, 75, 90, 120, 150]);
  });

  test('decimal amounts are remembered', () async {
    await amounts.add(62.5);
    await amounts.setDefault(62.5);

    final next = await reopened();

    expect(next.values, contains(62.5));
    expect(next.defaultAmount, 62.5);
  });

  test('refuses a repeated amount or one that is not above zero', () async {
    expect(await amounts.add(90), isFalse);
    expect(await amounts.add(0), isFalse);
    expect(await amounts.add(-5), isFalse);

    expect(amounts.values, FeedAmounts.premade);
  });

  test('the default is changed and remembered', () async {
    await amounts.setDefault(90);

    expect(amounts.defaultAmount, 90);
    expect((await reopened()).defaultAmount, 90);
  });

  test('only an amount in the list can be the default', () async {
    await amounts.setDefault(90);
    await amounts.setDefault(999);

    expect(amounts.defaultAmount, 90);
  });

  test('removing an amount is remembered', () async {
    await amounts.remove(90);

    expect((await reopened()).values, [60, 120, 150]);
  });

  test('removing another amount keeps the default', () async {
    await amounts.setDefault(120);

    await amounts.remove(90);

    expect(amounts.defaultAmount, 120);
  });

  test('removing the default makes the smallest left the default', () async {
    await amounts.setDefault(90);

    await amounts.remove(90);

    expect(amounts.defaultAmount, 60);
    expect((await reopened()).defaultAmount, 60);
  });

  test('all amounts can be removed, and stay removed', () async {
    for (final value in FeedAmounts.premade) {
      await amounts.remove(value);
    }

    final next = await reopened();

    expect(next.values, isEmpty);
    expect(next.defaultAmount, isNull);
  });

  test('the first amount added to an empty list is the default', () async {
    for (final value in FeedAmounts.premade) {
      await amounts.remove(value);
    }

    await amounts.add(80);

    expect(amounts.defaultAmount, 80);
    expect((await reopened()).defaultAmount, 80);
  });

  test('a damaged saved value is skipped', () async {
    settings.values['feed_amounts'] = '60,oops,90';
    settings.values['feed_amount_default'] = 'oops';

    final next = await reopened();

    expect(next.values, [60, 90]);
    expect(next.defaultAmount, 60);
  });
}
