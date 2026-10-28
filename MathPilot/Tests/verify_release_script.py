"""Exercise ship.sh with a fake xcodebuild; never archives or uploads anything."""
from pathlib import Path
import os, shutil, subprocess, tempfile
root = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='mathpilot-ship-test-') as directory:
    path = Path(directory)
    shutil.copy(root/'ship.sh', path/'ship.sh')
    shutil.copy(root/'ExportOptions.plist', path/'ExportOptions.plist')
    fake = path/'xcodebuild'
    fake.write_text('#!/bin/bash\nprintf "%s\\n" "$@" >> "$SHIP_TEST_LOG"\nprintf "CALL_END\\n" >> "$SHIP_TEST_LOG"\n')
    fake.chmod(0o755)
    for override in (None, '3'):
        log=path/('default.log' if override is None else 'override.log')
        env=dict(os.environ, PATH=str(path)+os.pathsep+os.environ['PATH'], SHIP_TEST_LOG=str(log))
        env.pop('BUILD_NUMBER',None)
        if override: env['BUILD_NUMBER']=override
        subprocess.run(['/bin/bash', str(path/'ship.sh')],env=env,check=True,stdout=subprocess.DEVNULL)
        calls=log.read_text().split('CALL_END\n')
        assert len(calls)==3
        for call in calls[:2]:
            for flag in ('-allowProvisioningUpdates','-authenticationKeyID','-authenticationKeyIssuerID','-authenticationKeyPath'):
                assert flag in call
        assert '-configuration\nRelease\n' in calls[0]
        if override: assert 'CURRENT_PROJECT_VERSION=3' in calls[0]
print('Release script checks passed: default and overridden build number; authentication on archive and export.')
