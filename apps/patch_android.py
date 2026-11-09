"""Run inside the generated Flutter project: python3 patch_android.py "<App label>" <icons dir>"""
import os, re, shutil, sys
label, icons = sys.argv[1], sys.argv[2]
m = 'android/app/src/main/AndroidManifest.xml'
s = open(m).read()
if 'permission.INTERNET' not in s:
    s = s.replace('<application', '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
s = re.sub(r'android:label="[^"]*"', f'android:label="{label}"', s, count=1)
open(m, 'w').write(s)
for d in os.listdir(icons):
    dst = f'android/app/src/main/res/{d}'
    if os.path.isdir(dst):
        shutil.copy(os.path.join(icons, d, 'ic_launcher.png'), os.path.join(dst, 'ic_launcher.png'))
gp = 'android/gradle.properties'
g = open(gp).read()
g = re.sub(r'org\.gradle\.jvmargs=.*', 'org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=1g', g)
open(gp, 'w').write(g)
kts = 'android/app/build.gradle.kts'
groovy = 'android/app/build.gradle'
if os.path.exists(kts):
    s = open(kts).read()
    block = '''    signingConfigs {
        create("qyra") {
            storeFile = file(System.getenv("QYRA_KEYSTORE") ?: "missing.jks")
            storePassword = System.getenv("QYRA_KEYSTORE_PASSWORD")
            keyAlias = "qyra"
            keyPassword = System.getenv("QYRA_KEYSTORE_PASSWORD")
        }
    }

    buildTypes {'''
    assert '    buildTypes {' in s, 'buildTypes block not found'
    s = s.replace('    buildTypes {', block, 1)
    s = s.replace('signingConfig = signingConfigs.getByName("debug")',
                  'signingConfig = if (System.getenv("QYRA_KEYSTORE").isNullOrEmpty()) signingConfigs.getByName("debug") else signingConfigs.getByName("qyra")', 1)
    open(kts, 'w').write(s)
elif os.path.exists(groovy):
    s = open(groovy).read()
    block = '''    signingConfigs {
        qyra {
            storeFile file(System.getenv("QYRA_KEYSTORE") ?: "missing.jks")
            storePassword System.getenv("QYRA_KEYSTORE_PASSWORD")
            keyAlias "qyra"
            keyPassword System.getenv("QYRA_KEYSTORE_PASSWORD")
        }
    }

    buildTypes {'''
    s = s.replace('    buildTypes {', block, 1)
    s = s.replace('signingConfig signingConfigs.debug',
                  'signingConfig (System.getenv("QYRA_KEYSTORE") ? signingConfigs.qyra : signingConfigs.debug)', 1)
    open(groovy, 'w').write(s)
print('Patched Android project for', label)
