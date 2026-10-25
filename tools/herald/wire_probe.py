"""Standard-library smoke test against LOCAL probe only; no production secrets."""
import hashlib
import hmac
import json
import secrets
import socket
import struct
import sys
import time
from urllib.parse import urlencode

KEY = 'a' * 64  # Deliberately synthetic; accepted only by the isolated probe config.


def sign(message):
    return hashlib.sha256(f'{KEY}|{message}|{KEY}'.encode('utf-8')).hexdigest()


def read_exact(stream, length):
    data = bytearray()
    while len(data) < length:
        chunk = stream.recv(length - len(data))
        if not chunk:
            raise ValueError('Incomplete BYOND frame')
        data.extend(chunk)
    return bytes(data)


def query(port, values):
    raw = ('?' + urlencode(values)).encode('ascii')
    assert len(raw) <= 16000
    with socket.create_connection(('127.0.0.1', port), timeout=8) as stream:
        stream.sendall(b'\x00\x83' + struct.pack('>H', len(raw) + 6) + b'\0' * 5 + raw + b'\0')
        header = read_exact(stream, 4)
        length = struct.unpack('>H', header[2:])[0]
        assert header[:2] == b'\x00\x83' and 2 <= length <= 60000
        response = read_exact(stream, length)
    assert response[0] == 6 and response[-1] == 0
    return json.loads(response[1:-1].decode('utf-8'))


def request(action, **kwargs):
    values = {'herald_read': action, 'ckey': '', 'offset': '0',
              'minute': str(int(time.time() // 60)), 'nonce': secrets.token_hex(16), 'operator': '2', **kwargs}
    text = 'request|' + '|'.join(values[name] for name in
        ('herald_read', 'ckey', 'offset', 'minute', 'nonce', 'operator'))
    values['signature'] = sign(text)
    return values


def validated(port, values):
    response = query(port, values)
    assert 'data' in response, response
    assert hmac.compare_digest(response['signature'], sign('response|' + values['nonce'] + '|' + response['data']))
    data = json.loads(response['data'])
    assert data['read_only'] == 1
    return data


def admin_request(action, round_id, ck, data, request_id=None):
    payload = json.dumps(data, ensure_ascii=False, sort_keys=True, separators=(',', ':'))
    values = {'herald_admin': action, 'round': round_id, 'ckey': ck, 'payload': payload,
              'minute': str(int(time.time() // 60)), 'request_id': request_id or secrets.token_hex(16), 'operator': '2'}
    digest = hashlib.sha256(payload.encode()).hexdigest()
    canonical = f'admin_request|{action}|{round_id}|{ck}|{digest}|{values["minute"]}|{values["request_id"]}|2'
    values['signature'] = sign(canonical)
    return values


def validated_admin(port, values):
    envelope = query(port, values)
    assert 'data' in envelope, envelope
    assert hmac.compare_digest(envelope['signature'], sign('admin_response|' + values['request_id'] + '|' + envelope['data']))
    data = json.loads(envelope['data'])
    assert data['request_id'] == values['request_id'] and data['ckey'] == values['ckey']
    return data


def duty_request(action, round_id=None, ck=None, data=None, request_id=None):
    values = {'herald_duty': action, 'minute': str(int(time.time() // 60)), 'operator': '2'}
    if action == 'snapshot':
        values['nonce'] = secrets.token_hex(16)
        canonical = f'duty_snapshot|{values["minute"]}|{values["nonce"]}|2'
    else:
        payload = json.dumps(data, ensure_ascii=False, sort_keys=True, separators=(',', ':'))
        values.update({'round': round_id, 'ckey': ck, 'payload': payload,
                       'request_id': request_id or secrets.token_hex(16)})
        digest = hashlib.sha256(payload.encode()).hexdigest()
        canonical = f'duty_request|{round_id}|{ck}|{digest}|{values["minute"]}|{values["request_id"]}|2'
    values['signature'] = sign(canonical)
    return values


def validated_duty(port, values):
    envelope = query(port, values)
    assert 'data' in envelope, envelope
    snapshot = values['herald_duty'] == 'snapshot'
    prefix = 'duty_snapshot_response' if snapshot else 'duty_response'
    identity = values['nonce'] if snapshot else values['request_id']
    assert hmac.compare_digest(envelope['signature'], sign(f'{prefix}|{identity}|' + envelope['data']))
    return json.loads(envelope['data'])


def main():
    port = int(sys.argv[1])
    for action in ('status', 'players', 'character'):
        values = request(action, ckey='notonline' if action == 'character' else '')
        snapshot = validated(port, values)
        round_id = str(snapshot['round'])
        print('PASS local_signed_' + action)
        time.sleep(2.2)  # World time can lag wall time during map startup.
    values = request('status')
    validated(port, values)
    time.sleep(2.2)
    assert query(port, values)['error'] == 'replayed_or_busy'
    assert query(port, {'herald_read': 'sdql'})['error'] == 'unsupported_action'
    invalid = request('status')
    invalid['signature'] = '0' * 64
    assert query(port, invalid)['error'] == 'unauthorized'
    print('PASS replay_unsupported_sdql_and_bad_signature_refused')
    # Isolated probe fake recipient. No live player and no real DB are contacted.
    reply = admin_request('reply', round_id, 'heraldwire', {'ticket_id': 998, 'text': 'Ответ из Discord 🐟'})
    assert validated_admin(port, reply)['status'] == 'delivered'
    duplicate = validated_admin(port, reply)
    assert duplicate['status'] == 'delivered' and duplicate['duplicate'] == 1
    print('PASS real_topic_admin_reply_and_idempotent_replay')
    time.sleep(3.1)
    pq = admin_request('pq', round_id, 'heraldpqprobe', {'delta': -1, 'reason': 'Local wire check'})
    result = validated_admin(port, pq)
    assert result['status'] == 'pq_adjusted' and result['before'] == 35 and result['after'] == 34
    assert validated_admin(port, pq)['duplicate'] == 1
    print('PASS real_topic_pq_change_and_idempotent_replay')
    bad = admin_request('kick', 'previous_round', 'notonline', {'reason': 'test'})
    assert query(port, bad)['error'] == 'wrong_round'
    bad = admin_request('kick', round_id, 'notonline', {'reason': 'test'})
    bad['signature'] = '0'*64
    assert query(port, bad)['error'] == 'unauthorized'
    assert query(port, {'herald_admin': 'sdql'})['error'] == 'unsupported_action'
    print('PASS admin_old_round_bad_signature_and_arbitrary_command_refused')
    snapshot = validated_duty(port, duty_request('snapshot'))
    assert snapshot['read_only'] == 1 and snapshot['duty_enabled'] == 1
    assert snapshot['admins'] == {'known': 1, 'active': 0, 'total': 0}
    ticket = next(row for row in snapshot['tickets'] if row['id'] == 995)
    assert ticket['ckey'] == 'heralddutywire' and ticket['last_interactions'][-1]['kind'] == 'player'
    reply = duty_request('reply', round_id, ticket['ckey'],
                         {'ticket_id': ticket['id'], 'version': ticket['version'], 'text': 'Я Геральд, автоматический дежурный. Проверяю обращение.'})
    result = validated_duty(port, reply)
    assert result['status'] == 'delivered' and result['new_version'] > ticket['version']
    assert validated_duty(port, reply)['duplicate'] == 1
    long_reply = duty_request('reply', round_id, ticket['ckey'],
                              {'ticket_id': ticket['id'], 'version': result['new_version'], 'text': 'слово ' * 31})
    assert query(port, long_reply)['error'] == 'invalid_argument'
    assert query(port, {'herald_duty': 'ban'})['error'] == 'unsupported_action'
    print('PASS duty_signed_snapshot_ai_reply_dedup_word_limit_no_punishment')


if __name__ == '__main__':
    main()
