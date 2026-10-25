-- Ricambi: richieste di ricambi per scheda/auto e fornitori (collegamenti di ricerca)
-- Accesso solo tramite funzioni con PIN (acc_chk); tabelle chiuse con RLS.

create table if not exists public.ric_richieste (
  id uuid primary key default gen_random_uuid(),
  scheda_id uuid,  -- id scheda accettazione (senza vincolo: la scheda può essere eliminata)
  targa text,
  descrizione text not null,
  codice text,
  fornitore text,
  prezzo numeric(10,2),
  qta int not null default 1,
  stato text not null default 'da_cercare'
    check (stato in ('da_cercare','cercato','ordinato','arrivato','annullato')),
  note text,
  richiesto_da text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  ordinato_at timestamptz,
  arrivato_at timestamptz
);
create index if not exists ric_richieste_stato_idx on public.ric_richieste(stato, created_at desc);
create index if not exists ric_richieste_scheda_idx on public.ric_richieste(scheda_id);

create table if not exists public.ric_fornitori (
  id serial primary key,
  nome text not null,
  url text,            -- modello di ricerca, es. https://sito.it/cerca?q={q}
  note text,
  attivo boolean not null default true
);

alter table public.ric_richieste enable row level security;
alter table public.ric_fornitori enable row level security;
revoke all on public.ric_richieste, public.ric_fornitori from anon, authenticated;
revoke all on sequence public.ric_fornitori_id_seq from anon, authenticated;

-- elenco richieste (con dati dell'auto)
create or replace function public.ric_list(p_u integer, p_p text, p_stato text default null)
returns jsonb language plpgsql security definer set search_path to 'public','extensions' as $$
begin
  perform acc_chk(p_u,p_p);
  return coalesce((select jsonb_agg(x order by (x->>'created_at') desc) from (
    select jsonb_build_object(
      'id',r.id,'scheda_id',r.scheda_id,'targa',coalesce(r.targa,s.targa),'descrizione',r.descrizione,
      'codice',r.codice,'fornitore',r.fornitore,'prezzo',r.prezzo,'qta',r.qta,'stato',r.stato,'note',r.note,
      'richiesto_da',r.richiesto_da,'created_at',r.created_at,'updated_at',r.updated_at,
      'ordinato_at',r.ordinato_at,'arrivato_at',r.arrivato_at,
      'marca',s.marca,'modello',s.modello,'telaio',s.telaio,'cliente',s.cliente_nome,'num',s.num) x
    from ric_richieste r left join acc_schede s on s.id=r.scheda_id
    where (p_stato is null or p_stato='' or r.stato=p_stato)
      and (r.stato not in ('arrivato','annullato') or r.updated_at > now() - interval '30 days')
    order by r.created_at desc limit 300) t),'[]'::jsonb);
end $$;

-- crea o aggiorna una richiesta
create or replace function public.ric_save(p_u integer, p_p text, p_r jsonb)
returns uuid language plpgsql security definer set search_path to 'public','extensions' as $$
declare n text; i uuid; st text;
begin
  n := acc_chk(p_u,p_p);
  st := coalesce(nullif(p_r->>'stato',''),'da_cercare');
  if st not in ('da_cercare','cercato','ordinato','arrivato','annullato') then raise exception 'Stato non valido'; end if;
  if nullif(trim(p_r->>'id'),'') is null then
    if nullif(trim(p_r->>'descrizione'),'') is null then raise exception 'Scrivi cosa serve'; end if;
    insert into ric_richieste(scheda_id,targa,descrizione,codice,fornitore,prezzo,qta,stato,note,richiesto_da,ordinato_at,arrivato_at)
    values (nullif(p_r->>'scheda_id','')::uuid, upper(nullif(trim(p_r->>'targa'),'')), trim(p_r->>'descrizione'),
      nullif(trim(p_r->>'codice'),''), nullif(trim(p_r->>'fornitore'),''), nullif(p_r->>'prezzo','')::numeric,
      greatest(coalesce(nullif(p_r->>'qta','')::int,1),1), st, nullif(trim(p_r->>'note'),''), n,
      case when st='ordinato' then now() end, case when st='arrivato' then now() end)
    returning id into i;
    return i;
  end if;
  i := (p_r->>'id')::uuid;
  update ric_richieste set
    descrizione = coalesce(nullif(trim(p_r->>'descrizione'),''),descrizione),
    codice = nullif(trim(p_r->>'codice'),''),
    fornitore = nullif(trim(p_r->>'fornitore'),''),
    prezzo = nullif(p_r->>'prezzo','')::numeric,
    qta = greatest(coalesce(nullif(p_r->>'qta','')::int,1),1),
    note = nullif(trim(p_r->>'note'),''),
    stato = st,
    ordinato_at = case when st='ordinato' and stato<>'ordinato' then now() else ordinato_at end,
    arrivato_at = case when st='arrivato' and stato<>'arrivato' then now() else arrivato_at end,
    updated_at = now()
  where id=i;
  if not found then raise exception 'Richiesta non trovata'; end if;
  return i;
end $$;

-- codici gia' usati per lo stesso modello (aiuto a trovare il codice giusto)
create or replace function public.ric_storico(p_u integer, p_p text, p_q text)
returns jsonb language plpgsql security definer set search_path to 'public','extensions' as $$
begin
  perform acc_chk(p_u,p_p);
  if length(trim(coalesce(p_q,'')))<2 then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(x) from (
    select jsonb_build_object('descrizione',r.descrizione,'codice',r.codice,'fornitore',r.fornitore,
      'prezzo',r.prezzo,'marca',s.marca,'modello',s.modello,'targa',coalesce(r.targa,s.targa),'data',r.created_at) x
    from ric_richieste r left join acc_schede s on s.id=r.scheda_id
    where r.codice is not null and r.stato<>'annullato'
      and (coalesce(s.modello,'') ilike '%'||trim(p_q)||'%' or coalesce(s.marca,'') ilike '%'||trim(p_q)||'%'
           or r.descrizione ilike '%'||trim(p_q)||'%' or r.codice ilike '%'||trim(p_q)||'%')
    order by r.created_at desc limit 12) t),'[]'::jsonb);
end $$;

-- fornitori (collegamenti di ricerca)
create or replace function public.ric_forn_list(p_u integer, p_p text)
returns jsonb language plpgsql security definer set search_path to 'public','extensions' as $$
begin
  perform acc_chk(p_u,p_p);
  return coalesce((select jsonb_agg(jsonb_build_object('id',id,'nome',nome,'url',url,'note',note) order by nome)
    from ric_fornitori where attivo),'[]'::jsonb);
end $$;

create or replace function public.ric_forn_save(p_u integer, p_p text, p_f jsonb)
returns int language plpgsql security definer set search_path to 'public','extensions' as $$
declare i int;
begin
  perform acc_chk(p_u,p_p);
  if nullif(trim(p_f->>'nome'),'') is null then raise exception 'Scrivi il nome del fornitore'; end if;
  if nullif(p_f->>'id','') is null then
    insert into ric_fornitori(nome,url,note) values (trim(p_f->>'nome'), nullif(trim(p_f->>'url'),''), nullif(trim(p_f->>'note'),''))
    returning id into i;
  else
    i := (p_f->>'id')::int;
    update ric_fornitori set nome=trim(p_f->>'nome'), url=nullif(trim(p_f->>'url'),''), note=nullif(trim(p_f->>'note'),''),
      attivo = coalesce((p_f->>'attivo')::boolean,true) where id=i;
  end if;
  return i;
end $$;

revoke all on function public.ric_list(integer,text,text), public.ric_save(integer,text,jsonb),
  public.ric_storico(integer,text,text), public.ric_forn_list(integer,text), public.ric_forn_save(integer,text,jsonb) from public;
grant execute on function public.ric_list(integer,text,text), public.ric_save(integer,text,jsonb),
  public.ric_storico(integer,text,text), public.ric_forn_list(integer,text), public.ric_forn_save(integer,text,jsonb) to anon, authenticated;
