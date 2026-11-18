-- =====================================================================
-- 초등학교 특별실 예약 시스템 테이블 (Supabase / PostgreSQL)
-- Supabase 대시보드 > SQL Editor > New query 에 붙여 넣고 Run 하세요.
-- =====================================================================

-- [다시 실행할 때만] 기존 테이블을 지우고 처음부터 만들려면 아래 두 줄의 주석(--)을 풀고 실행하세요.
-- drop table if exists reservations;                                   -- 예약 테이블 삭제 (rooms를 참조하므로 먼저 삭제)
-- drop table if exists rooms;                                          -- 특별실 테이블 삭제


-- ---------------------------------------------------------------------
-- 1. 특별실 목록 테이블
-- ---------------------------------------------------------------------
create table rooms (                                                    -- 특별실 테이블 생성 시작
  id bigint generated always as identity primary key,                   -- 특별실 고유 번호 (1, 2, 3 ... 자동 증가, 기본 키)
  name text not null unique,                                            -- 특별실 이름 (반드시 입력, 같은 이름 중복 불가)
  location text                                                         -- 특별실 위치 (예: 본관 3층, 비워 둘 수 있음)
);                                                                      -- 특별실 테이블 생성 끝


-- ---------------------------------------------------------------------
-- 2. 예약 테이블
-- ---------------------------------------------------------------------
create table reservations (                                             -- 예약 테이블 생성 시작
  id bigint generated always as identity primary key,                   -- 예약 고유 번호 (자동 증가, 기본 키)
  room_id bigint not null                                               -- 예약한 특별실 번호 (반드시 입력)
    references rooms(id) on delete cascade,                             -- rooms.id 를 참조 (특별실이 삭제되면 그 예약도 함께 삭제)
  reserved_date date not null,                                          -- 예약 날짜 (예: 2026-11-02)
  period smallint not null                                              -- 교시 (반드시 입력)
    check (period between 1 and 6),                                     -- 교시는 1~6만 허용 (7교시 같은 값은 거부)
  teacher_name text not null                                            -- 예약한 교사 이름 (학생 정보는 저장하지 않음)
    check (char_length(teacher_name) between 1 and 20),                 -- 이름은 1~20자만 허용
  grade smallint not null                                               -- 사용 학년 (반드시 입력)
    check (grade between 1 and 6),                                      -- 학년은 1~6만 허용
  class_no smallint                                                     -- 사용 반 (비워 둘 수 있음)
    check (class_no between 1 and 15),                                  -- 반은 1~15만 허용
  purpose text                                                          -- 사용 목적 (예: 과학 실험, 비워 둘 수 있음)
    check (char_length(purpose) <= 100),                                -- 사용 목적은 100자 이하
  created_at timestamptz not null default now(),                        -- 예약을 저장한 시각 (자동 기록)
  constraint no_double_booking                                          -- ★ 이중 예약 방지 규칙의 이름
    unique (room_id, reserved_date, period)                             -- ★ 같은 특별실 + 같은 날짜 + 같은 교시는 단 한 건만 저장
);                                                                      -- 예약 테이블 생성 끝


-- ---------------------------------------------------------------------
-- 3. 접근 정책 (RLS: Row Level Security)
--    브라우저는 공개 키(publishable key, 구 anon key)로 접속하며,
--    이때 DB 역할은 anon 입니다. 아래 정책이 허용한 일만 할 수 있습니다.
-- ---------------------------------------------------------------------
alter table rooms enable row level security;                            -- 특별실 테이블에 RLS 켜기 (정책 없으면 아무것도 못 함)
alter table reservations enable row level security;                     -- 예약 테이블에 RLS 켜기

create policy "rooms_select_anon"                                       -- 정책 이름: 특별실 조회 허용
  on rooms for select                                                   -- rooms 테이블의 조회(select)에 적용
  to anon                                                               -- 로그인하지 않은 사용자(anon)에게
  using (true);                                                         -- 모든 행 조회 허용

create policy "reservations_select_anon"                                -- 정책 이름: 예약 조회 허용
  on reservations for select                                            -- reservations 테이블의 조회에 적용
  to anon                                                               -- anon 에게
  using (true);                                                         -- 모든 예약 조회 허용 (시간표를 보여 주기 위해)

create policy "reservations_insert_anon"                                -- 정책 이름: 예약 추가 허용
  on reservations for insert                                            -- reservations 테이블의 추가(insert)에 적용
  to anon                                                               -- anon 에게
  with check (true);                                                    -- 추가 허용 (값 검사는 위의 check·unique 제약이 담당)

create policy "reservations_delete_anon"                                -- 정책 이름: 예약 삭제(취소) 허용
  on reservations for delete                                            -- reservations 테이블의 삭제(delete)에 적용
  to anon                                                               -- anon 에게
  using (true);                                                         -- ⚠ 누구나 모든 예약 삭제 가능 (수업용, 실제 운영에는 로그인 필요)

-- rooms 에는 insert/update/delete 정책이 없으므로 브라우저에서 특별실을 바꿀 수 없습니다.
-- reservations 에는 update 정책이 없으므로 예약 수정도 불가 (취소 후 다시 예약).


-- ---------------------------------------------------------------------
-- 4. 테이블 사용 권한 (앱에서 permission denied 오류가 날 때를 대비)
-- ---------------------------------------------------------------------
grant select on rooms to anon;                                          -- anon 에게 특별실 조회 권한 부여
grant select, insert, delete on reservations to anon;                   -- anon 에게 예약 조회·추가·삭제 권한 부여


-- ---------------------------------------------------------------------
-- 5. 샘플 특별실 6개
-- ---------------------------------------------------------------------
insert into rooms (name, location) values                               -- 특별실 데이터 넣기 시작
  ('과학실',   '본관 3층'),                                            -- 1번: 과학실
  ('음악실',   '별관 2층'),                                            -- 2번: 음악실
  ('컴퓨터실', '본관 2층'),                                            -- 3번: 컴퓨터실
  ('미술실',   '별관 1층'),                                            -- 4번: 미술실
  ('체육관',   '체육관동'),                                            -- 5번: 체육관
  ('도서실',   '본관 1층');                                            -- 6번: 도서실


-- ---------------------------------------------------------------------
-- 6. 확인용 조회 (실행 후 결과 창에 특별실 6개가 보이면 성공)
-- ---------------------------------------------------------------------
select * from rooms order by id;                                        -- 특별실 목록을 번호 순으로 보기
