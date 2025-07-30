import os
import shutil

base_folder = '/Applications/World of Warcraft/_retail_/Interface/AddOns/SharedMedia_ONS/sound'
subfolder = os.path.join(base_folder,'unusedSounds' )

# checking to see the subfolder exists
os.makedirs(subfolder, exist_ok=True)

file_to_move = [
    '318_MoveToSkull.mp3',
    '319_MoveToCross.mp3',
]

for file_name in file_to_move:
    src = os.path.join(base_folder, file_name)
    dst = os.path.join(subfolder, file_name)

    # check to make sure the file exists before we move the files 
    if os.path.exists(src):
        shutil.move(src, dst)
        print(f"\033[92mMoved {file_name} to {subfolder}\033[0m")
    else:
        print(f"\033[91m{file_name} does not exist in {base_folder}\033[0m")

