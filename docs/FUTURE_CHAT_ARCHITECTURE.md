# Future Patient–Doctor chat: design only

The current app shows locked **Coming Soon** consultation controls alongside saved-screening feedback and in the Doctor workspace. They make no chat request, approval or message API calls. Structured Doctor feedback remains the real clinical workflow; a submitted review never automatically opens a conversation.

## Proposed authorization path

1. A Patient owns a saved screening and uses the existing review-request flow. An Admin assigns a verified Doctor. The Doctor submits a structured review.
2. A future Patient chat request must name that reviewed case and its *currently assigned* Doctor. Server-side checks must confirm screening ownership, active assignment, Doctor verification, case eligibility and no duplicate active chat request.
3. Only that Doctor may approve or decline. A declined or pending request never enables sending. Approval creates one private conversation tied to the case and request.
4. Every read and send checks a valid Clerk session, resolved role, participant membership, approved request, active Doctor authorization, account state and case state at request time. UI visibility is not authorization.
5. Assignment revocation or Doctor suspension must stop new messages and reading until a documented retention/access policy determines the final archive behavior. Case closure should similarly transition the conversation to read-only or closed after an explicit product decision.

Admins manage Doctor verification and case assignment, not routine chat approval. Admin roles should not automatically read medical conversations. Any exceptional access needs a separately justified, audited policy.

## Candidate data model, not a migration

| Entity | Minimum fields and constraints |
| --- | --- |
| `chat_requests` | ID, patient Clerk subject, Doctor Clerk subject, screening/review-request ID, pending/approved/declined/cancelled state, requested and decision timestamps. Foreign keys to the current case records. Unique active request per case/Doctor; decision actor must be the assigned Doctor. |
| `conversations` | ID, approved request ID (unique), case ID, active/closed state, created and closed timestamps. Created only from an approved request. |
| `messages` | ID, conversation ID, sender Clerk subject, bounded content, created timestamp. Append through authenticated server operations with per-message authorization. |
| `message_read_states` | Optional per-participant last-read marker if read receipts become necessary. |

Use existing Clerk subjects, `review_requests`, `case_assignments` and `doctor_profiles` rather than separate role records. Define RLS policies for both participants and private Storage only if attachments become necessary. Do not add attachments, payments, calling, typing indicators or real-time infrastructure until requirements and security tests justify them.

Before implementation, establish informed consent language, retention and deletion policy, moderation/escalation policy, audit scope, access after revocation and account deletion, rate limits and notification privacy. Never place tokens, private image URLs or medical message bodies in ordinary logs. Test Patient B denial, unrelated Doctor denial, pending/declined denial, suspended Doctor denial, revoked assignment denial, duplicate request prevention and concurrent decision handling.
