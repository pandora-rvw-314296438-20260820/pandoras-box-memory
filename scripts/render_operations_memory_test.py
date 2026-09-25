#!/usr/bin/env python3
"""Render the exact native Memory SQL plus the new bridge for an empty test database."""
from pathlib import Path
import argparse
import sys
ROOT = Path(__file__).resolve().parents[1]
def render(mode='all'):
    native=(ROOT/'supabase/migrations/20260901184935_pandora_provider_learning_v1.sql').read_text(encoding='utf-8')
    start=native.index('create or replace function public.memory_ingest_model_outcome_candidate_v1(')
    end=native.index('end $$;',start)+len('end $$;')
    context=(ROOT/'supabase/migrations/20260913143500_m5_task_aware_retrieval_v1.sql').read_text(encoding='utf-8')
    migrations=list((ROOT/'supabase/migrations').glob('*_pandora_operations_memory_bridge_v1.sql'))
    if len(migrations)!=1: raise ValueError('Expected one exact operations Memory migration')
    setup='\n'.join([(ROOT/'tests/operations-memory/fixture.sql').read_text(encoding='utf-8'),native[start:end],context,migrations[0].read_text(encoding='utf-8')])
    behavior=(ROOT/'tests/operations-memory/behavior.sql').read_text(encoding='utf-8')
    return setup if mode=='setup' else behavior if mode=='behavior' else setup+'\n'+behavior
if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--mode',choices=['all','setup','behavior'],default='all')
    args=parser.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')
    print(render(args.mode))
