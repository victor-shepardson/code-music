from os import symlink, makedirs
import re

def mkdir(path):
    makedirs(path, exist_ok=True)

src_root = '/Users/victor/Music/sample/'
dest_root = '/Users/victor/Music/sample/dirt/'
instruments = [
    dict(
        src_prefix = 'VSCO-2-CE/Woodwinds/Bassoon/vib/',
        dest_prefix = 'bassoon_vib/',
        files = [
            'PSBassoon_C2_v1_1.wav',
            'PSBassoon_C3_v1_1.wav',
            'PSBassoon_C4_v1_1.wav',
        ]),
    dict(
        src_prefix = 'VSCO-2-CE/Woodwinds/Bassoon/sus/',
        dest_prefix = 'bassoon_sus/',
        files = [
            'PSBassoon_C2_v1_1.wav',
            'PSBassoon_C3_v1_1.wav',
            'PSBassoon_C4_v1_1.wav',
        ]),
    dict(
        src_prefix = 'VSCO-2-CE/Woodwinds/Bassoon/stac/',
        dest_prefix = 'bassoon_stac/',
        files = [
            'PSBassoon_C2_v1_rr1.wav',
            'PSBassoon_C3_v1_rr1.wav',
            'PSBassoon_C4_v1_rr1.wav',
        ]),
    dict(
        src_prefix = 'Reverb Casio CZ1000 Synth Collection Sample Pack/Reverb Casio CZ1000 Synth Collection Sample Pack_Audio Files/Violin Lead/',
        dest_prefix = 'cz_violin/',
        files = [
            'Casio CZ1000 Violin Lead_C1.wav',
            'Casio CZ1000 Violin Lead_C2.wav',
            'Casio CZ1000 Violin Lead_C3.wav',
            'Casio CZ1000 Violin Lead_C4.wav',
        ]),
    dict(
        src_prefix = 'Reverb Oberheim Matrix 1000 Synth Collection Sample Pack/Reverb Oberheim Matrix 1000 Synth Collection Sample Pack_Audio/Bass2/',
        dest_prefix = 'matrix_bass/',
        files = [
            'Matrix 1000 Bass2_C1.wav',
            'Matrix 1000 Bass2_C2.wav',
            'Matrix 1000 Bass2_C3.wav',
            'Matrix 1000 Bass2_C4.wav',
            'Matrix 1000 Bass2_C5.wav',
        ]),
    dict(
        src_prefix = '',
        dest_prefix = 'ride/',
        files = [
            ('Reverb Drum Machines | The Complete Collection/',[
                ('Reverb E-mu Drumulator Sample Pack/',[
                    ('Reverb E-mu Drumulator_Audio Files/', [
                        'Reverb E-mu Drumulator Sample Pack_Ride.wav'
                    ]),
                ]),
            ]),
        ]),
    dict(
        src_prefix = '',
        dest_prefix = 'perc/',
        files = [
            ('Reverb Drum Machines | The Complete Collection/', [
                ('Reverb Roland Rhythm 77 Sample Pack/', [
                    ('Reverb Roland Rhythm 77 Sample Pack_Audio Files/', [
                        'Reverb Roland Rhythm 77 Sample Pack_Snap.wav',
                        'Reverb Roland Rhythm 77 Sample Pack_Tamborine.wav',
                        'Reverb Roland Rhythm 77 Sample Pack_Wood Block.wav',

                    ]),
                ]),
            ]),
        ]),
    ]

whitespace = re.compile('\s+')

def walk(file_tree, prefix=''):
    if isinstance(file_tree, list):
        return sum((walk(item, prefix) for item in file_tree), [])
    if isinstance(file_tree, str):
        return [(prefix, file_tree)]
    else:
        node, children = file_tree
        return walk(children, prefix+node)

for inst in instruments:
    for i,(src_middle, src_file) in enumerate(walk(inst['files'])):
        file_prefix = f'{i:04}_'
        src_dir = src_root+inst['src_prefix']+src_middle
        dest_dir = dest_root+inst['dest_prefix']
        mkdir(dest_dir)
        dest_file = file_prefix + re.sub(whitespace, '_', src_file)
        dest_path = dest_dir+dest_file
        try:
            symlink(src_dir+src_file, dest_path)
            print(dest_path)
        except FileExistsError:
            print(f'{dest_path} already present')
