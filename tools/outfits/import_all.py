#!/usr/bin/env python3
"""GitHub build entry point. No importing or editing is exposed in the game."""
import argparse
from pathlib import Path
from custom_outfits import import_directory

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo',type=Path,default=Path(__file__).resolve().parents[2])
    parser.add_argument('--rbxmk',default='rbxmk')
    args=parser.parse_args()
    imported=import_directory(args.repo,args.rbxmk)
    print('Prepared costumes: '+(', '.join(imported) if imported else 'none uploaded; manifest refreshed'))

if __name__=='__main__':main()
