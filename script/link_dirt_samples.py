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
        src_prefix = 'VSCO-2-CE/Woodwinds/Flute/stac/',
        dest_prefix = 'flute_stac/',
        files = [
            'LDFlute_stac_C4_v1_rr2.wav',
            'LDFlute_stac_C5_v1_rr2.wav',
            'LDFlute_stac_C6_v1_rr2.wav',
        ]),
    dict(
        src_prefix = 'VSCO-2-CE/Woodwinds/Flute/susNV/',
        dest_prefix = 'flute/',
        files = [
            'LDFlute_susNV_C3_v3_1.wav',
            'LDFlute_susNV_C4_v1_1.wav',
            'LDFlute_susNV_C5_v1_1.wav',
            'LDFlute_susNV_C6_v1_1.wav',
        ]),
    dict(
        src_prefix = 'VSCO-2-CE/Woodwinds/Flute/expvib/',
        dest_prefix = 'flute_vib/',
        files = [
            'LDFlute_expvib_C3_v1_1.wav',
            'LDFlute_expvib_C4_v1_1.wav',
            'LDFlute_expvib_C5_v1_1.wav',
            'LDFlute_expvib_C6_v1_1.wav',
        ]),
    dict( # TODO: resample (maybe just change sampling rate of file?) to get more C tones
        src_prefix = 'VSCO-2-CE/Strings/Harp/',
        dest_prefix = 'harp/',
        files = [
            'KSHarp_C3_mf.wav',
            'KSHarp_C5_mf.wav',
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
        src_prefix = 'Reverb Casio CZ1000 Synth Collection Sample Pack/Reverb Casio CZ1000 Synth Collection Sample Pack_Audio Files/Accordian/',
        dest_prefix = 'cz_accordian/',
        files = [
            'Casio CZ1000 Accordian_C1.wav',
            'Casio CZ1000 Accordian_C2.wav',
            'Casio CZ1000 Accordian_C3.wav',
            'Casio CZ1000 Accordian_C4.wav',
        ]),
    dict(
        src_prefix = 'Reverb Casio CZ1000 Synth Collection Sample Pack/Reverb Casio CZ1000 Synth Collection Sample Pack_Audio Files/Whistle/',
        dest_prefix = 'cz_whistle/',
        files = [
            'Casio CZ1000 Whistle_C1.wav',
            'Casio CZ1000 Whistle_C2.wav',
            'Casio CZ1000 Whistle_C3.wav',
            'Casio CZ1000 Whistle_C4.wav',
        ]),
    dict(
        src_prefix = 'Reverb Casio CZ1000 Synth Collection Sample Pack/Reverb Casio CZ1000 Synth Collection Sample Pack_Audio Files/Trumpet/',
        dest_prefix = 'cz_trumpet/',
        files = [
            'Casio CZ1000 Trumpet_C1.wav',
            'Casio CZ1000 Trumpet_C2.wav',
            'Casio CZ1000 Trumpet_C3.wav',
            'Casio CZ1000 Trumpet_C4.wav',
        ]),
    dict(
        src_prefix = 'Reverb Casio CZ1000 Synth Collection Sample Pack/Reverb Casio CZ1000 Synth Collection Sample Pack_Audio Files/Electric Organ/',
        dest_prefix = 'cz_organ/',
        files = [
            'Casio CZ1000 Electric Organ_C1.wav',
            'Casio CZ1000 Electric Organ_C2.wav',
            'Casio CZ1000 Electric Organ_C3.wav',
            'Casio CZ1000 Electric Organ_C4.wav',
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
        src_prefix = 'Reverb Oberheim Matrix 1000 Synth Collection Sample Pack/Reverb Oberheim Matrix 1000 Synth Collection Sample Pack_Audio/',
        dest_prefix = 'matrix_lead/',
        files = [
            ('Lead1/',['Matrix 1000 Lead1_C1.wav']),
            ('Lead5/',['Matrix 1000 Lead5_C2.wav']),
            ('Lead4/',['Matrix 1000 Lead4_C3.wav']),
            ('Lead3/',['Matrix 1000 Lead3_C4.wav']),
            ('Lead2/',['Matrix 1000 Lead2_C5.wav']),
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
                ('Reverb Roland TR 505 Sample Pack/', [
                    ('Reverb Roland TR 505 Sample Pack_Audio Files/', [
                        'Reverb Roland TR 505 Sample Pack_Ride.wav',
                    ]),
                ]),
                ('Reverb Suzuki RPM-40 Sample Pack/', [
                    ('Reverb Suzuki RPM-40 Sample Pack_Audio Files/', [
                        'Reverb Suzuki RPM-40 Sample Pack_Ride.wav',
                    ]),
                ]),
                ('Reverb Roland TR-808 Sample Pack/', [
                    ('Reverb Roland TR-808 Sample Pack_Audio Files/', [
                        ('Reverb Roland TR-808 Sample Pack_Cymbal/', [
                            'Reverb Roland TR-808 Sample Pack_Cymbal Accent Max Decay.wav',
                        ]),
                    ]),
                ]),
                ('Reverb Oberheim DMX Sample Pack/', [
                    ('Reverb Oberheim DMX Sample Pack_Audio Files/', [
                        'Reverb Oberheim DMX Sample Pack_Ride.wav',
                    ]),
                ]),
            ]),
            ('VSCO-2-CE/', [
                ('VSCO 1 Percussion/', [
                    ('varMetal/', [
                        ('Gong/', [
                            'gong_smack_3.wav',
                            'gong_smack_2.wav',
                            'gong_scrape_1.wav',
                        ]),
                    ]),
                ]),
            ]),
        ]),
    dict(
        src_prefix = '',
        dest_prefix = 'crash/',
        files = [
            ('Reverb Drum Machines | The Complete Collection/', [
                ('Reverb Modded Roland TR-909 Sample Pack/', [
                    ('Reverb Modded Roland TR-909 Sample Pack_Audio Files/', [
                        ('CC - CRASH CYMBAL/', [
                            'CC - High.wav',
                            'CC - Med 1.wav',
                        ]),
                    ]),
                ]),
            ]),
            ('Reverb Vintage Drums Vol. 1/', [
                ('Reverb Vintage Drums Vol. 1 One Shots/', [
                    'Crash Two.wav',
                ]),
            ]),
            ('VSCO-2-CE/', [
                ('VSCO 1 Percussion/', [
                    ('varMetal/', [
                        ('Cymbals/', [
                            ('susp/', [
                                'susp_hit_hardmall_fff.wav',
                            ]),
                        ]),
                    ]),
                ]),
            ]),
        ]),
    dict(
        src_prefix = '',
        dest_prefix = 'hat/',
        files = [
            ('Reverb Drum Machines | The Complete Collection/', [
                ('Reverb Modded Roland TR-909 Sample Pack/', [
                    ('Reverb Modded Roland TR-909 Sample Pack_Audio Files/', [
                        ('OH - OPEN HAT/', [
                            'OH - Short Decay.wav',
                        ]),
                    ]),
                ]),
                ('Reverb Ace Tone Rhythm Fever Sample Pack/', [
                    ('Reverb Ace Tone Rhythm Fever Sample Pack_Audio Files/', [
                        'Reverb Ace Tone Rhythm Fever Sample Pack_OHH1.wav',
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
                ('Reverb Roland Rhythm Arranger Sample Pack/', [
                    ('Reverb Roland Rhythm Arranger Sample Pack_Audio Files/', [
                        'Perc4.wav',
                    ]),
                ]),
                ('Reverb Roland Rhythm 330 Sample Pack/', [
                    ('Reverb Roland Rhythm 330 Sample Pack_Audio Files/', [
                        'Perc1.wav',
                    ]),
                ]),
                ('Reverb Roland TR 505 Sample Pack/', [
                    ('Reverb Roland TR 505 Sample Pack_Audio Files/', [
                        'Reverb Roland TR 505 Sample Pack_Rim.wav',
                    ]),
                ]),
                ('Reverb Modded Roland TR-909 Sample Pack/', [
                    ('Reverb Modded Roland TR-909 Sample Pack_Audio Files/', [
                        ('RS - RIM SHOT/', [
                            'RS - 3.wav',
                        ]),
                    ]),
                ]),
                ('Reverb Ace Tone Rhythm Fever Sample Pack/', [
                    ('Reverb Ace Tone Rhythm Fever Sample Pack_Audio Files/', [
                        'Reverb Ace Tone Rhythm Fever Sample Pack_Perc5.wav',
                    ]),
                ]),
                ('Reverb LinnDrum Sample Pack/', [
                    ('Reverb LinnDrum Sample Pack_Audio Files/', [
                        'Reverb LinnDrum Sample Pack_Tambourine Soft.wav',
                    ]),
                ]),
                ('Reverb Oberheim DMX Sample Pack/', [
                    ('Reverb Oberheim DMX Sample Pack_Audio Files/', [
                        'Reverb Oberheim DMX Sample Pack_Tamborine.wav',
                    ]),
                ]),
            ]),
            ('VSCO-2-CE/', [
                ('VSCO 1 Percussion/', [
                    ('varWood/', [
                        'slapstick3.wav',
                        'tambourine_Down.wav',
                        'tambourine_up_7.wav',
                    ]),
                    ('varMetal/', [
                        ('various/', [
                            'bell_tree_metalscrape1.wav',
                            'brake_mf_1.wav',
                            'cabasa_4.wav',
                            'sleighbell1_hit_1.wav',
                            'windchimes_fastAsc1.wav',
                        ]),
                        ('Cymbals/', [
                            ('susp/', [
                                'susp_hit_metal_2_f.wav',
                            ]),
                        ]),
                    ])
                ]),
            ]),
        ]),
    dict(
        src_prefix = '',
        dest_prefix = 'skin/',
        files = [
            ('Reverb Drum Machines | The Complete Collection/', [
                ('Reverb Roland TR 505 Sample Pack/', [
                    ('Reverb Roland TR 505 Sample Pack_Audio Files/', [
                        'Reverb Roland TR 505 Sample Pack_Tom1.wav',
                        'Reverb Roland TR 505 Sample Pack_Tom2.wav',
                        'Reverb Roland TR 505 Sample Pack_Tom3.wav',
                        'Reverb Roland TR 505 Sample Pack_Conga Low.wav',
                    ]),
                ]),
                ('Reverb Suzuki RPM-40 Sample Pack/', [
                    ('Reverb Suzuki RPM-40 Sample Pack_Audio Files/', [
                        'Reverb Suzuki RPM-40 Sample Pack_Tom.wav',
                    ]),
                ]),
                ('Reverb Modded Roland TR-909 Sample Pack/', [
                    ('Reverb Modded Roland TR-909 Sample Pack_Audio Files/', [
                        ('HT - HI TOM/', [
                            'HT.1 MOD [NOISE] 4.wav',
                        ]),
                        ('MT - MID TOM/', [
                            'MT.1 - High Tune Long Decay.wav',
                        ]),
                    ]),
                ]),
                ('Reverb Roland TR-808 Sample Pack/', [
                    ('Reverb Roland TR-808 Sample Pack_Audio Files/', [
                        ('Reverb Roland TR-808 Sample Pack_Toms/', [
                            'Reverb Roland TR-808 Sample Pack_Tom Low Accent Min Decay.wav',
                        ]),
                    ]),
                ]),
                ('Reverb Oberheim DMX Sample Pack/', [
                    ('Reverb Oberheim DMX Sample Pack_Audio Files/', [
                        'Reverb Oberheim DMX Sample Pack_Tom1.wav',
                        'Reverb Oberheim DMX Sample Pack_Tom6.wav',
                    ]),
                ]),
            ]),
        ]),
    dict(
        src_prefix = '',
        dest_prefix = 'kick/',
        files = [
            ('Reverb Drum Machines | The Complete Collection/', [
                ('Reverb Roland TR 505 Sample Pack/', [
                    ('Reverb Roland TR 505 Sample Pack_Audio Files/', [
                        'Reverb Roland TR 505 Sample Pack_Kick.wav',
                    ]),
                ]),
                ('Reverb Roland Rhythm 330 Sample Pack/', [
                    ('Reverb Roland Rhythm 330 Sample Pack_Audio Files/', [
                        'Kick.wav',
                    ]),
                ]),
                ('Reverb Suzuki RPM-40 Sample Pack/', [
                    ('Reverb Suzuki RPM-40 Sample Pack_Audio Files/', [
                        'Reverb Suzuki RPM-40 Sample Pack_Kick.wav',
                    ]),
                ]),
                ('Reverb Modded Roland TR-909 Sample Pack/', [
                    ('Reverb Modded Roland TR-909 Sample Pack_Audio Files/', [
                        ('BD - BASS DRUM/', [
                            'BD.1 - High Tune Med Decay.wav',
                            'BD.1 MOD [Pitch+Depth] 2.wav',
                            'BD.1 MOD [Pitch+Depth] 11.wav'
                        ]),
                    ]),
                ]),
                ('Reverb Sequential Circuits DrumTraks Sample Pack/', [
                    ('Reverb Sequential Circuits DrumTraks Sample Pack_Audio Files/', [
                        'Reverb Sequential Circuits DrumTraks Sample Pack_Kick.wav',
                    ]),
                ]),
                ('Reverb Roland TR-909 Sample Pack/', [
                    ('Reverb Roland TR-909 Sample Pack_Audio Files/', [
                        ('Reverb Roland TR-909 Sample Pack_Kick/', [
                            'Reverb Roland TR-909 Sample Pack_Kick Accent Low Tone Min Attack Max Decay.wav',
                        ]),
                    ]),
                ]),
                ('Reverb LinnDrum Sample Pack/', [
                    ('Reverb LinnDrum Sample Pack_Audio Files/', [
                        'Reverb LinnDrum Sample Pack_Kick Hard.wav',
                    ]),
                ]),
                ('Reverb Roland Modded TR-707 Sample Pack/', [
                    ('Reverb Roland Modded TR-707 Sample Pack_Audio Files/', [
                        ('Reverb Roland Modded TR-707 Sample Pack_Kick/', [
                            'Reverb Roland Modded TR-707 Sample Pack_Kick4.wav',
                            'Reverb Roland Modded TR-707 Sample Pack_Kick2.wav',
                            'Reverb Roland Modded TR-707 Sample Pack_Kick7.wav',
                            'Reverb Roland Modded TR-707 Sample Pack_Kick13.wav',
                        ]),
                    ]),
                ]),
            ]),
        ]),
    dict(
        src_prefix = '',
        dest_prefix = 'snare/',
        files = [
            ('Reverb Drum Machines | The Complete Collection/', [
                ('Reverb Roland TR 505 Sample Pack/', [
                    ('Reverb Roland TR 505 Sample Pack_Audio Files/', [
                        'Reverb Roland TR 505 Sample Pack_Snare.wav',
                    ]),
                ]),
                ('Reverb Modded Roland TR-909 Sample Pack/', [
                    ('Reverb Modded Roland TR-909 Sample Pack_Audio Files/', [
                        ('SN - SNARE DRUM/', [
                            'SN.1 - Low Tune Med Tone.wav',
                        ]),
                    ]),
                ]),
            ]),
        ]),
    dict(
        src_prefix = '',
        dest_prefix = 'noise/',
        files = [
            ('VSCO-2-CE/', [
                ('VSCO 1 Percussion/', [
                    ('varWood/', [
                        'ratchet1.wav',
                        'maraca_shake.wav',
                        'tambourine_shake.wav'
                    ]),
                    ('varMetal/', [
                        ('various/', [
                            'cabasa_roll2.wav',
                            'sleighbell2_shake1.wav',
                            'windchimes_slowDesc1.wav',
                        ]),
                    ]),
                ]),
            ]),
        ]),
    dict(
        src_prefix = 'VSCO-2-CE/Miscellania Raw/Misc 1/',
        dest_prefix = 'zap/',
        files = [
            'zap1.wav',
            'zap2.wav',
            'zap3.wav',
            'zap4.wav',
            'zap5.wav',
            'zap6.wav',
            'zap7.wav',
            'zap8.wav',
            'zap9.wav',
            'zap10.wav',
            'zap11.wav',
            'zap12.wav',
            'zap13.wav',
            'zap14.wav',
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
            print(f'🌞\t{dest_path}')
        except FileExistsError:
            print(f'👁\t{dest_path}')
