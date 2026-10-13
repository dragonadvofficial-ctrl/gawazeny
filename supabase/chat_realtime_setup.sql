-- ============================================================================
-- PLATFORM: جوزيني يا ماما (Serious Marriage Matching Platform)
-- SCRIPT: Secure Realtime Chat System — Tables, RLS, Triggers, Realtime
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. CONVERSATIONS TABLE
-- One conversation per mutual match (UNIQUE on match_id).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS conversations (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id         UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  user_one         UUID NOT NULL REFERENCES profiles(id),
  user_two         UUID NOT NULL REFERENCES profiles(id),
  last_message     TEXT,
  last_message_at  TIMESTAMPTZ DEFAULT now(),
  created_at       TIMESTAMPTZ DEFAULT now(),

  CONSTRAINT conversations_match_id_key UNIQUE (match_id)
);

-- ----------------------------------------------------------------------------
-- 2. MESSAGES TABLE
-- All messages reference their parent conversation.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS messages (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id  UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id        UUID NOT NULL REFERENCES profiles(id),
  content          TEXT NOT NULL,
  is_read          BOOLEAN DEFAULT false,
  created_at       TIMESTAMPTZ DEFAULT now()
);

-- Index for fast conversation message loading
CREATE INDEX IF NOT EXISTS messages_conversation_id_created_at_idx
  ON messages (conversation_id, created_at DESC);

-- Index for unread badge counts
CREATE INDEX IF NOT EXISTS messages_is_read_sender_idx
  ON messages (conversation_id, is_read, sender_id);

-- ----------------------------------------------------------------------------
-- 3. TRIGGER: Auto-update last_message & last_message_at on INSERT
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_conversation_last_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE conversations
  SET
    last_message = NEW.content,
    last_message_at = NEW.created_at
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_new_message ON messages;
CREATE TRIGGER on_new_message
AFTER INSERT ON messages
FOR EACH ROW
EXECUTE FUNCTION update_conversation_last_message();

-- ----------------------------------------------------------------------------
-- 4. RLS — CONVERSATIONS
-- Both participants must exist; both must be VERIFIED.
-- ----------------------------------------------------------------------------
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "conv_select_participant" ON conversations;
CREATE POLICY "conv_select_participant"
ON conversations FOR SELECT
TO authenticated
USING (
  (auth.uid() = user_one OR auth.uid() = user_two)
  AND EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
      AND verification_status = 'VERIFIED'
  )
);

DROP POLICY IF EXISTS "conv_insert_participant" ON conversations;
CREATE POLICY "conv_insert_participant"
ON conversations FOR INSERT
TO authenticated
WITH CHECK (
  (auth.uid() = user_one OR auth.uid() = user_two)
  AND EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
      AND verification_status = 'VERIFIED'
  )
);

DROP POLICY IF EXISTS "conv_update_participant" ON conversations;
CREATE POLICY "conv_update_participant"
ON conversations FOR UPDATE
TO authenticated
USING (auth.uid() = user_one OR auth.uid() = user_two);

-- ----------------------------------------------------------------------------
-- 5. RLS — MESSAGES
-- Sender/receiver must be verified; no blocked relationships.
-- ----------------------------------------------------------------------------
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "msg_select_participant" ON messages;
CREATE POLICY "msg_select_participant"
ON messages FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM conversations c
    WHERE c.id = conversation_id
      AND (c.user_one = auth.uid() OR c.user_two = auth.uid())
  )
  AND NOT EXISTS (
    SELECT 1 FROM blocked_users
    WHERE (blocker_id = auth.uid() AND blocked_id IN (
        SELECT CASE WHEN user_one = auth.uid() THEN user_two ELSE user_one END
        FROM conversations WHERE id = conversation_id
      ))
       OR (blocked_id = auth.uid() AND blocker_id IN (
        SELECT CASE WHEN user_one = auth.uid() THEN user_two ELSE user_one END
        FROM conversations WHERE id = conversation_id
      ))
  )
);

DROP POLICY IF EXISTS "msg_insert_own" ON messages;
CREATE POLICY "msg_insert_own"
ON messages FOR INSERT
TO authenticated
WITH CHECK (
  sender_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM conversations c
    WHERE c.id = conversation_id
      AND (c.user_one = auth.uid() OR c.user_two = auth.uid())
  )
  AND EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
      AND verification_status = 'VERIFIED'
  )
);

DROP POLICY IF EXISTS "msg_update_read" ON messages;
CREATE POLICY "msg_update_read"
ON messages FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM conversations c
    WHERE c.id = conversation_id
      AND (c.user_one = auth.uid() OR c.user_two = auth.uid())
  )
);

-- ----------------------------------------------------------------------------
-- 6. SUPABASE REALTIME — Enable publication on both tables
-- ----------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE messages;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'conversations'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE conversations;
  END IF;
END;
$$;

-- ----------------------------------------------------------------------------
-- 7. RPC: get_or_create_conversation
-- Validates mutual match + VERIFIED status, then upserts conversation.
-- Returns conversation_id.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_or_create_conversation(
  p_match_id UUID,
  p_partner_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id  UUID := auth.uid();
  v_conv_id  UUID;
  v_my_status TEXT;
  v_partner_status TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Verify the match exists and both users are participants
  IF NOT EXISTS (
    SELECT 1 FROM matches m
    WHERE m.id = p_match_id AND m.is_active = true
      AND (m.user_one_id = v_user_id OR m.user_two_id = v_user_id)
  ) THEN
    RETURN jsonb_build_object('error', 'NO_MATCH', 'message', 'لا يوجد توافق نشط');
  END IF;

  -- Check verification status
  SELECT verification_status::TEXT INTO v_my_status
    FROM profiles WHERE id = v_user_id;

  SELECT verification_status::TEXT INTO v_partner_status
    FROM profiles WHERE id = p_partner_id;

  IF v_my_status != 'VERIFIED' THEN
    RETURN jsonb_build_object('error', 'NOT_VERIFIED', 'message', 'يجب توثيق هويتك أولاً لبدء المحادثة');
  END IF;

  IF v_partner_status != 'VERIFIED' THEN
    RETURN jsonb_build_object('error', 'PARTNER_NOT_VERIFIED', 'message', 'الطرف الآخر لم يُوثّق هويته بعد');
  END IF;

  -- Check for block in either direction
  IF EXISTS (
    SELECT 1 FROM blocked_users
    WHERE (blocker_id = v_user_id AND blocked_id = p_partner_id)
       OR (blocker_id = p_partner_id AND blocked_id = v_user_id)
  ) THEN
    RETURN jsonb_build_object('error', 'BLOCKED', 'message', 'تعذر فتح المحادثة بسبب الحظر');
  END IF;

  -- Upsert conversation
  INSERT INTO conversations (match_id, user_one, user_two)
  VALUES (p_match_id, v_user_id, p_partner_id)
  ON CONFLICT (match_id) DO UPDATE SET match_id = EXCLUDED.match_id
  RETURNING id INTO v_conv_id;

  RETURN jsonb_build_object(
    'conversation_id', v_conv_id,
    'my_status', v_my_status,
    'partner_status', v_partner_status
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 8. RPC: mark_messages_read
-- Marks all messages in a conversation as read for the current user.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mark_messages_read(p_conversation_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE messages
  SET is_read = true
  WHERE conversation_id = p_conversation_id
    AND sender_id != auth.uid()
    AND is_read = false;
END;
$$;
