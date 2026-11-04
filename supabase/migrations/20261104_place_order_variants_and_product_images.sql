-- Função place_order com suporte a variantes (cor, tamanho, número, armazenamento)
-- e bucket público de fotos de produtos.

create or replace function public.place_order(p_name text, p_phone text, p_delivery text, p_payment text, p_quote_mode text, p_items jsonb)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  e jsonb; v_qty int; v_p record; v_var record; v_var_id uuid; v_price numeric(12,2);
  v_label text; v_lines jsonb := '[]'::jsonb; v_total numeric(12,2) := 0; v_level smallint := 1;
  v_cust uuid; v_ord uuid; v_code text; v_status text;
begin
  if coalesce(length(trim(p_name)), 0) not between 2 and 120 or coalesce(length(trim(p_phone)), 0) not between 6 and 30 then
    raise exception 'invalid_customer' using errcode = '22023';
  end if;
  if jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) not between 1 and 50 then
    raise exception 'invalid_items' using errcode = '22023';
  end if;
  if p_quote_mode is not null and p_quote_mode not in ('personalizada','automatica') then
    raise exception 'invalid_quote_mode' using errcode = '22023';
  end if;
  for e in select * from jsonb_array_elements(p_items) loop
    v_qty := (e->>'quantity')::int;
    if v_qty is null or v_qty not between 1 and 100 then raise exception 'invalid_quantity' using errcode = '22023'; end if;
    select p.id, p.name, p.price_mzn, p.availability, coalesce(p.checkout_level, c.checkout_level) as lvl into v_p
      from public.products p
      join public.subcategories s on s.id = p.subcategory_id
      join public.categories c on c.id = s.category_id
     where p.id = (e->>'product_id')::uuid and p.is_published and private.sub_visible(p.subcategory_id);
    if not found or v_p.availability = 'X' then raise exception 'product_unavailable' using errcode = '22023'; end if;

    v_var_id := nullif(e->>'variant_id', '')::uuid;
    v_price := v_p.price_mzn;
    v_label := null;
    if v_var_id is not null then
      select pv.price_mzn, pv.options into v_var
        from public.product_variants pv
       where pv.id = v_var_id and pv.product_id = v_p.id and pv.is_active;
      if not found then raise exception 'product_unavailable' using errcode = '22023'; end if;
      v_price := coalesce(v_var.price_mzn, v_p.price_mzn);
      select string_agg(o.k || ': ' || o.val, ' · ') into v_label
        from jsonb_each_text(v_var.options) as o(k, val);
    end if;

    v_total := v_total + v_price * v_qty;
    v_level := greatest(v_level, v_p.lvl, case when v_price < 3000 then 1 when v_price < 15000 then 2 when v_price < 60000 then 3 else 4 end);
    v_lines := v_lines || jsonb_build_array(jsonb_build_object(
      'product_id', v_p.id,
      'variant_id', v_var_id,
      'product_name', case when v_label is null then v_p.name else v_p.name || ' (' || v_label || ')' end,
      'price', v_price,
      'qty', v_qty));
  end loop;

  v_status := case when v_level = 4 and coalesce(p_quote_mode, 'personalizada') = 'personalizada' then 'awaiting_confirmation'
                   when v_level = 4 then 'payment_pending' else 'received' end;
  loop
    v_code := 'MT-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
    exit when not exists (select 1 from public.orders where code = v_code);
  end loop;
  insert into public.customers (name, phone) values (trim(p_name), trim(p_phone)) returning id into v_cust;
  insert into public.orders (code, customer_id, status, checkout_level, quote_mode, delivery_method, payment_method, total_mzn)
  values (v_code, v_cust, v_status, v_level, case when v_level = 4 then coalesce(p_quote_mode, 'personalizada') end, left(p_delivery, 80), left(p_payment, 80), v_total)
  returning id into v_ord;
  insert into public.order_items (order_id, product_id, variant_id, product_name, unit_price_mzn, quantity)
  select v_ord, (x->>'product_id')::uuid, nullif(x->>'variant_id', '')::uuid, x->>'product_name', (x->>'price')::numeric, (x->>'qty')::int
    from jsonb_array_elements(v_lines) x;
  return jsonb_build_object('code', v_code, 'status', v_status, 'total_mzn', v_total, 'checkout_level', v_level);
end $function$;

-- Bucket público para fotos de produtos (leitura pública; escrita só para administradores)
insert into storage.buckets (id, name, public) values ('product-images', 'product-images', true)
  on conflict (id) do update set public = true;

drop policy if exists "product images public read" on storage.objects;
create policy "product images public read" on storage.objects for select to anon, authenticated
  using (bucket_id = 'product-images');

drop policy if exists "product images admin write" on storage.objects;
create policy "product images admin write" on storage.objects for all to authenticated
  using (bucket_id = 'product-images' and private.is_admin())
  with check (bucket_id = 'product-images' and private.is_admin());
