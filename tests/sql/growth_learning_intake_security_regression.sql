do $$
declare before_candidates bigint; before_reviews bigint; payload jsonb; encoded_text text;
begin
  select count(*) into before_candidates from public.memory_capture_candidates;
  select count(*) into before_reviews from public.memory_review_queue_items;
  encoded_text:=chr(65)||chr(117)||chr(116)||chr(104)||chr(111)||chr(114)||
    chr(105)||chr(122)||chr(97)||chr(116)||chr(105)||chr(111)||chr(110)||
    chr(58)||chr(9)||chr(66)||chr(101)||chr(97)||chr(114)||chr(101)||
    chr(114)||chr(32)||'synthetic';

  payload:=public.test_growth_payload(
    'verified_fact','learning-decoded-value',null
  );
  payload:=jsonb_set(
    payload,'{growth_learning,candidate,claim}',to_jsonb(encoded_text)
  );
  begin
    perform public.memory_ingest_growth_learning_v1(
      '99999999-9999-4999-8999-999999999999',payload
    );
    raise exception 'expected decoded value rejection';
  exception when sqlstate '22023' then
    if sqlerrm not like '%GROWTH_LEARNING_SENSITIVE_MATERIAL_REJECTED%' then raise; end if;
  end;

  payload:=public.test_growth_payload(
    'verified_fact','learning-decoded-key',null
  );
  payload:=jsonb_set(
    payload,'{growth_learning,candidate}',
    (payload#>'{growth_learning,candidate}')||jsonb_build_object(encoded_text,'x')
  );
  begin
    perform public.memory_ingest_growth_learning_v1(
      '99999999-9999-4999-8999-999999999999',payload
    );
    raise exception 'expected decoded key rejection';
  exception when sqlstate '22023' then
    if sqlerrm not like '%GROWTH_LEARNING_SENSITIVE_MATERIAL_REJECTED%' then raise; end if;
  end;

  if (select count(*) from public.memory_capture_candidates)<>before_candidates
    or (select count(*) from public.memory_review_queue_items)<>before_reviews then
    raise exception 'decoded string rejection changed state';
  end if;
end $$;

do $$
declare first_receipt jsonb; terminal_receipt jsonb; payload jsonb;
begin
  payload:=public.test_growth_payload(
    'verified_fact','learning-reviewed-replay',null
  );
  first_receipt:=public.memory_ingest_growth_learning_v1(
    '99999999-9999-4999-8999-999999999999',payload
  );
  update public.memory_review_queue_items
     set status='approved_for_append'
   where id=(first_receipt->>'review_item_id')::uuid;

  terminal_receipt:=public.memory_ingest_growth_learning_v1(
    '99999999-9999-4999-8999-999999999999',payload
  );
  if terminal_receipt->>'status'<>'already_reviewed'
    or terminal_receipt->>'review_status'<>'approved_for_append'
    or terminal_receipt->>'candidate_id'<>first_receipt->>'candidate_id'
    or terminal_receipt->>'review_item_id'<>first_receipt->>'review_item_id'
    or terminal_receipt->'deduplicated' is distinct from 'true'::jsonb then
    raise exception 'terminal reviewed replay receipt mismatch';
  end if;
end $$;

do $$
begin
  if has_function_privilege(
    'service_role',
    'private.pandora_growth_learning_contains_sensitive_v1(jsonb)',
    'execute'
  ) then
    raise exception 'private decoded-string helper must not be directly service-callable';
  end if;
end $$;

select 'growth_learning_security_regression PASS' as result;
