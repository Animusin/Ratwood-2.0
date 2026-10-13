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
    assert len(raw) <= 2048
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


def main():
    port = int(sys.argv[1])
    for action in ('status', 'players', 'character'):
        values = request(action, ckey='notonline' if action == 'character' else '')
        validated(port, values)
        print('PASS local_signed_' + action)
        time.sleep(1.1)
    values = request('status')
    validated(port, values)
    time.sleep(1.1)
    assert query(port, values)['error'] == 'replayed_or_busy'
    assert query(port, {'herald_read': 'sdql'})['error'] == 'unsupported_action'
    invalid = request('status')
    invalid['signature'] = '0' * 64
    assert query(port, invalid)['error'] == 'unauthorized'
    print('PASS replay_unsupported_sdql_and_bad_signature_refused')


if __name__ == '__main__':
    main()
