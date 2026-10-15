#!/usr/bin/env python3
"""Replace a standalone Evolution image without exporting secrets or deleting mounts.

Default is a read-only preflight. --apply creates the candidate before stopping
the current container, keeps the latter as a stopped backup and never rolls back.
"""
import argparse
import copy
import datetime
import json
import pathlib
import subprocess
import urllib.parse


def docker(*args):
    return subprocess.check_output(['docker', *args], text=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--container', default='evolution-api')
    parser.add_argument('--image', required=True)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--allow-missing-compose-source', action='store_true',
                        help='Preserve stale Compose labels only when every original config file is absent.')
    args = parser.parse_args()
    original = json.loads(docker('inspect', args.container))[0]
    image = json.loads(docker('image', 'inspect', args.image))[0]
    if not original['State']['Running']:
        raise RuntimeError('The current service must be running before replacement.')
    if original['HostConfig'].get('AutoRemove') or original['HostConfig'].get('VolumesFrom'):
        raise RuntimeError('AutoRemove/VolumesFrom require a separate reviewed procedure.')
    labels = original['Config'].get('Labels') or {}
    if labels.get('com.docker.compose.project'):
        sources = labels.get('com.docker.compose.project.config_files', '').split(',')
        if not args.allow_missing_compose_source or not all(sources) or any(pathlib.Path(path).is_file() for path in sources):
            raise RuntimeError('Compose-managed Evolution must be updated through its existing Compose service. Missing-source cases require explicit review.')
    if original['HostConfig']['NetworkMode'] in ('host', 'none') or original['HostConfig']['NetworkMode'].startswith('container:'):
        raise RuntimeError('This helper requires named Docker networks.')
    if image['Os'] != 'linux' or image['Architecture'] != json.loads(docker('image', 'inspect', original['Image']))[0]['Architecture']:
        raise RuntimeError('Image platform mismatch.')

    payload = copy.deepcopy(original['Config'])
    payload['Image'] = args.image
    payload['HostConfig'] = copy.deepcopy(original['HostConfig'])
    # Explicitly preserve existing anonymous/named volume sources too. Never
    # let an image VOLUME declaration create a replacement empty session volume.
    payload['HostConfig']['Mounts'] = payload['HostConfig'].get('Mounts') or []
    mapped = {mount['Target'] for mount in payload['HostConfig']['Mounts']}
    for binding in payload['HostConfig'].get('Binds') or []:
        mapped.add(binding.split(':')[1])
    for mount in original['Mounts']:
        if mount['Destination'] in mapped:
            continue
        if mount['Type'] not in ('bind', 'volume'):
            raise RuntimeError('Unsupported mount type; stop for review.')
        value = {'Type': mount['Type'], 'Source': mount.get('Name') or mount['Source'],
                 'Target': mount['Destination'], 'ReadOnly': not mount['RW']}
        if mount['Type'] == 'volume':
            value['VolumeOptions'] = {'NoCopy': True}
        payload['HostConfig'].setdefault('Mounts', []).append(value)
    endpoints = {}
    for name, network in original['NetworkSettings']['Networks'].items():
        aliases = [alias for alias in network.get('Aliases') or [] if alias not in (original['Id'], original['Id'][:12])]
        endpoints[name] = {'Aliases': list(dict.fromkeys([*aliases, args.container]))}
        if network.get('IPAMConfig'):
            raise RuntimeError('Static endpoint IP needs a separate reviewed replacement to avoid conflicts.')
    payload['NetworkingConfig'] = {'EndpointsConfig': endpoints}
    print(json.dumps({'mode': 'apply' if args.apply else 'preflight', 'container': args.container,
                      'old_image': original['Image'], 'new_image': image['Id'],
                      'stale_compose_labels_preserved': bool(labels.get('com.docker.compose.project')),
                      'networks': list(endpoints), 'mount_destinations': [m['Destination'] for m in original['Mounts']],
                      'environment_preserved': payload['Env'] == original['Config']['Env'],
                      'port_bindings_preserved': payload['HostConfig']['PortBindings'] == original['HostConfig']['PortBindings']}))
    if not args.apply:
        return

    suffix = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d%H%M%S')
    candidate = f'{args.container}-reactions-candidate-{suffix}'
    backup = f'{args.container}-before-reactions-{suffix}'
    # The full configuration stays in process memory, not a file/log. The Docker
    # socket has the same access requirement as the docker commands above.
    response = subprocess.run(['curl', '--silent', '--show-error', '--fail', '--unix-socket', '/var/run/docker.sock',
                               '-H', 'Content-Type: application/json', '-X', 'POST',
                               'http://localhost/containers/create?name=' + urllib.parse.quote(candidate),
                               '--data-binary', '@-'], input=json.dumps(payload), text=True, capture_output=True)
    if response.returncode:
        raise RuntimeError('Candidate creation failed. Current service was not stopped; no secrets printed.')
    candidate_id = json.loads(response.stdout)['Id']
    created = json.loads(docker('inspect', candidate_id))[0]
    old_mounts = sorted((m['Destination'], m['Source'], m['RW']) for m in original['Mounts'])
    new_mounts = sorted((m['Destination'], m['Source'], m['RW']) for m in created['Mounts'])
    if old_mounts != new_mounts or created['Config']['Env'] != original['Config']['Env']:
        raise RuntimeError('Candidate differs in mounts/environment; current service remains running. Review candidate manually.')
    if created['HostConfig']['PortBindings'] != original['HostConfig']['PortBindings'] or set(created['NetworkSettings']['Networks']) != set(endpoints):
        raise RuntimeError('Candidate differs in ports/networks; current service remains running. Review candidate manually.')
    docker('stop', '--time', '30', args.container)
    docker('rename', args.container, backup)
    docker('rename', candidate, args.container)
    docker('start', args.container)
    print(json.dumps({'started': args.container, 'backup_container': backup, 'automatic_rollback': False}))


if __name__ == '__main__':
    main()
