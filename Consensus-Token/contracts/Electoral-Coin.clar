;; Governance Token with Voting Delegation
;; A comprehensive token contract with delegation, checkpoints, and governance features

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_BALANCE (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_ALREADY_DELEGATED (err u103))
(define-constant ERR_SELF_DELEGATION (err u104))
(define-constant ERR_INVALID_RECIPIENT (err u105))
(define-constant ERR_INVALID_SPENDER (err u106))
(define-constant ERR_INSUFFICIENT_ALLOWANCE (err u107))
(define-constant ERR_INVALID_BLOCK (err u108))
(define-constant ERR_PAUSED (err u999))
(define-constant ERR_INVALID_INPUT (err u109))

;; Token Properties
(define-fungible-token governance-token)
(define-data-var token-name (string-ascii 32) "GovernanceToken")
(define-data-var token-symbol (string-ascii 10) "GOV")
(define-data-var token-decimals uint u6)
(define-data-var total-supply uint u0)
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var paused bool false)

;; Delegation mappings
(define-map delegates principal principal)
(define-map delegate-count principal uint)

;; Checkpoint system for historical voting power
(define-map checkpoints 
  {account: principal, checkpoint: uint} 
  {block-height: uint, votes: uint})
(define-map num-checkpoints principal uint)

;; Allowances for spending delegation
(define-map allowances {owner: principal, spender: principal} uint)

;; =============================================================================
;; VALIDATION HELPERS
;; =============================================================================

;; Validate string is not empty
(define-private (is-valid-string (str (string-ascii 32)))
  (> (len str) u0))

;; Validate symbol is not empty
(define-private (is-valid-symbol (symbol (string-ascii 10)))
  (> (len symbol) u0))

;; Validate decimals is reasonable (0-18)
(define-private (is-valid-decimals (decimals uint))
  (<= decimals u18))

;; Validate principal is not zero address
(define-private (is-valid-principal (addr principal))
  (not (is-eq addr 'SP000000000000000000002Q6VF78)))

;; Validate URI length if provided
(define-private (is-valid-uri (uri (optional (string-utf8 256))))
  (match uri
    some-uri (and (> (len some-uri) u0) (<= (len some-uri) u256))
    true)) ;; None is always valid

;; Validate amount is reasonable (not exceeding max supply limits)
(define-private (is-valid-amount (amount uint))
  (and (> amount u0) (<= amount u340282366920938463463374607431768211455)))

;; =============================================================================
;; READ-ONLY FUNCTIONS (No interdependencies)
;; =============================================================================

;; Get token name
(define-read-only (get-name)
  (ok (var-get token-name)))

;; Get token symbol
(define-read-only (get-symbol)
  (ok (var-get token-symbol)))

;; Get token decimals
(define-read-only (get-decimals)
  (ok (var-get token-decimals)))

;; Get total supply
(define-read-only (get-total-supply)
  (ok (ft-get-supply governance-token)))

;; Get token URI
(define-read-only (get-token-uri)
  (ok (var-get token-uri)))

;; Get balance of an account
(define-read-only (get-balance (account principal))
  (ok (ft-get-balance governance-token account)))

;; Check if contract is paused
(define-read-only (is-paused)
  (ok (var-get paused)))

;; Get current delegate of an account
(define-read-only (get-delegate (account principal))
  (ok (default-to account (map-get? delegates account))))

;; Get current votes (delegated voting power) of an account
(define-read-only (get-current-votes (account principal))
  (ok (default-to u0 (map-get? delegate-count account))))

;; Get allowance between owner and spender
(define-read-only (get-allowance (owner principal) (spender principal))
  (ok (default-to u0 (map-get? allowances {owner: owner, spender: spender}))))

;; Get number of checkpoints for an account
(define-read-only (get-num-checkpoints (account principal))
  (ok (default-to u0 (map-get? num-checkpoints account))))

;; Get specific checkpoint data
(define-read-only (get-checkpoint (account principal) (checkpoint uint))
  (ok (map-get? checkpoints {account: account, checkpoint: checkpoint})))

;; Check if account has delegated (not to self)
(define-read-only (has-delegated (account principal))
  (let ((current-delegate (default-to account (map-get? delegates account))))
    (ok (not (is-eq account current-delegate)))))

;; Get checkpoint data helper
(define-read-only (get-checkpoint-data (account principal) (checkpoint uint))
  (default-to 
    {block-height: u0, votes: u0}
    (map-get? checkpoints {account: account, checkpoint: checkpoint})))

;; Get historical votes at a specific block height (simplified)
(define-read-only (get-prior-votes (account principal) (target-block uint))
  (let ((num-checkpoints-val (default-to u0 (map-get? num-checkpoints account))))
    (if (is-eq num-checkpoints-val u0)
      (ok u0)
      (let ((latest-checkpoint (get-checkpoint-data account (- num-checkpoints-val u1))))
        (if (<= (get block-height latest-checkpoint) target-block)
          (ok (get votes latest-checkpoint))
          (ok u0)))))) ;; Simplified - just return 0 if target block is before latest

;; Get detailed account info
(define-read-only (get-account-info (account principal))
  (ok {
    balance: (ft-get-balance governance-token account),
    delegate: (default-to account (map-get? delegates account)),
    votes: (default-to u0 (map-get? delegate-count account)),
    checkpoints: (default-to u0 (map-get? num-checkpoints account))
  }))

;; Get contract info
(define-read-only (get-contract-info)
  (ok {
    name: (var-get token-name),
    symbol: (var-get token-symbol),
    decimals: (var-get token-decimals),
    total-supply: (ft-get-supply governance-token),
    paused: (var-get paused),
    owner: CONTRACT_OWNER
  }))

;; =============================================================================
;; PUBLIC FUNCTIONS (Self-contained, no cross-dependencies)
;; =============================================================================

;; Initialize token (only contract owner)
(define-public (initialize (initial-supply uint) (name (string-ascii 32)) (symbol (string-ascii 10)) (decimals uint) (uri (optional (string-utf8 256))))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-eq (var-get total-supply) u0) ERR_UNAUTHORIZED)
    (asserts! (> initial-supply u0) ERR_INVALID_AMOUNT)
    ;; Validate inputs
    (asserts! (is-valid-string name) ERR_INVALID_INPUT)
    (asserts! (is-valid-symbol symbol) ERR_INVALID_INPUT)
    (asserts! (is-valid-decimals decimals) ERR_INVALID_INPUT)
    (asserts! (is-valid-uri uri) ERR_INVALID_INPUT)
    
    ;; Set token properties
    (var-set token-name name)
    (var-set token-symbol symbol)
    (var-set token-decimals decimals)
    (var-set token-uri uri)
    
    ;; Mint initial supply to contract owner
    (try! (ft-mint? governance-token initial-supply CONTRACT_OWNER))
    (var-set total-supply initial-supply)
    
    ;; Set initial delegation to self
    (map-set delegates CONTRACT_OWNER CONTRACT_OWNER)
    (map-set delegate-count CONTRACT_OWNER initial-supply)
    
    ;; Create initial checkpoint
    (map-set checkpoints 
      {account: CONTRACT_OWNER, checkpoint: u0}
      {block-height: stacks-block-height, votes: initial-supply})
    (map-set num-checkpoints CONTRACT_OWNER u1)
    
    (print {event: "initialized", supply: initial-supply, owner: CONTRACT_OWNER})
    (ok true)))

;; Pause contract (only owner)
(define-public (pause)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set paused true)
    (print {event: "paused"})
    (ok true)))

;; Unpause contract (only owner)
(define-public (unpause)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set paused false)
    (print {event: "unpaused"})
    (ok true)))

;; Transfer tokens (self-contained)
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (not (var-get paused)) ERR_PAUSED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (is-eq sender tx-sender) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq sender recipient)) ERR_INVALID_RECIPIENT)
    
    ;; Get current delegates
    (let ((sender-delegate (default-to sender (map-get? delegates sender)))
          (recipient-delegate (default-to recipient (map-get? delegates recipient)))
          (current-block stacks-block-height))
      
      ;; Transfer tokens
      (try! (ft-transfer? governance-token amount sender recipient))
      
      ;; Update sender delegate votes
      (let ((sender-votes (default-to u0 (map-get? delegate-count sender-delegate))))
        (let ((new-sender-votes (if (>= sender-votes amount) (- sender-votes amount) u0)))
          (map-set delegate-count sender-delegate new-sender-votes)
          ;; Write checkpoint for sender delegate
          (let ((sender-checkpoints (default-to u0 (map-get? num-checkpoints sender-delegate))))
            (map-set checkpoints 
              {account: sender-delegate, checkpoint: sender-checkpoints}
              {block-height: current-block, votes: new-sender-votes})
            (map-set num-checkpoints sender-delegate (+ sender-checkpoints u1)))))
      
      ;; Update recipient delegate votes
      (let ((recipient-votes (default-to u0 (map-get? delegate-count recipient-delegate))))
        (let ((new-recipient-votes (+ recipient-votes amount)))
          (map-set delegate-count recipient-delegate new-recipient-votes)
          ;; Write checkpoint for recipient delegate
          (let ((recipient-checkpoints (default-to u0 (map-get? num-checkpoints recipient-delegate))))
            (map-set checkpoints 
              {account: recipient-delegate, checkpoint: recipient-checkpoints}
              {block-height: current-block, votes: new-recipient-votes})
            (map-set num-checkpoints recipient-delegate (+ recipient-checkpoints u1)))))
      
      (print {event: "transfer", from: sender, to: recipient, amount: amount})
      (ok true))))

;; Approve spending allowance
(define-public (approve (spender principal) (amount uint))
  (begin
    (asserts! (not (var-get paused)) ERR_PAUSED)
    (asserts! (not (is-eq spender tx-sender)) ERR_INVALID_SPENDER)
    (asserts! (is-valid-principal spender) ERR_INVALID_INPUT)
    (asserts! (is-valid-amount amount) ERR_INVALID_INPUT)
    (map-set allowances {owner: tx-sender, spender: spender} amount)
    (print {event: "approval", owner: tx-sender, spender: spender, amount: amount})
    (ok true)))

;; Transfer from (using allowance) - self-contained
(define-public (transfer-from (sender principal) (recipient principal) (amount uint) (memo (optional (buff 34))))
  (let ((allowance (default-to u0 (map-get? allowances {owner: sender, spender: tx-sender}))))
    (begin
      (asserts! (not (var-get paused)) ERR_PAUSED)
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      (asserts! (>= allowance amount) ERR_INSUFFICIENT_ALLOWANCE)
      (asserts! (not (is-eq sender recipient)) ERR_INVALID_RECIPIENT)
      
      ;; Update allowance
      (map-set allowances {owner: sender, spender: tx-sender} (- allowance amount))
      
      ;; Get current delegates
      (let ((sender-delegate (default-to sender (map-get? delegates sender)))
            (recipient-delegate (default-to recipient (map-get? delegates recipient)))
            (current-block stacks-block-height))
        
        ;; Transfer tokens
        (try! (ft-transfer? governance-token amount sender recipient))
        
        ;; Update sender delegate votes
        (let ((sender-votes (default-to u0 (map-get? delegate-count sender-delegate))))
          (let ((new-sender-votes (if (>= sender-votes amount) (- sender-votes amount) u0)))
            (map-set delegate-count sender-delegate new-sender-votes)
            ;; Write checkpoint for sender delegate
            (let ((sender-checkpoints (default-to u0 (map-get? num-checkpoints sender-delegate))))
              (map-set checkpoints 
                {account: sender-delegate, checkpoint: sender-checkpoints}
                {block-height: current-block, votes: new-sender-votes})
              (map-set num-checkpoints sender-delegate (+ sender-checkpoints u1)))))
        
        ;; Update recipient delegate votes
        (let ((recipient-votes (default-to u0 (map-get? delegate-count recipient-delegate))))
          (let ((new-recipient-votes (+ recipient-votes amount)))
            (map-set delegate-count recipient-delegate new-recipient-votes)
            ;; Write checkpoint for recipient delegate
            (let ((recipient-checkpoints (default-to u0 (map-get? num-checkpoints recipient-delegate))))
              (map-set checkpoints 
                {account: recipient-delegate, checkpoint: recipient-checkpoints}
                {block-height: current-block, votes: new-recipient-votes})
              (map-set num-checkpoints recipient-delegate (+ recipient-checkpoints u1)))))
        
        (print {event: "transfer-from", from: sender, to: recipient, amount: amount, spender: tx-sender})
        (ok true)))))

;; Delegate voting power (self-contained)
(define-public (delegate (delegatee principal))
  (let ((delegator tx-sender)
        (current-delegate (default-to delegator (map-get? delegates delegator)))
        (delegator-balance (ft-get-balance governance-token delegator))
        (current-block stacks-block-height))
    (begin
      (asserts! (not (var-get paused)) ERR_PAUSED)
      (asserts! (not (is-eq delegator delegatee)) ERR_SELF_DELEGATION)
      (asserts! (is-valid-principal delegatee) ERR_INVALID_INPUT)
      
      ;; Update delegation mapping
      (map-set delegates delegator delegatee)
      
      ;; Remove votes from current delegate
      (let ((current-votes (default-to u0 (map-get? delegate-count current-delegate))))
        (let ((new-current-votes (if (>= current-votes delegator-balance) (- current-votes delegator-balance) u0)))
          (map-set delegate-count current-delegate new-current-votes)
          ;; Write checkpoint for current delegate
          (let ((current-checkpoints (default-to u0 (map-get? num-checkpoints current-delegate))))
            (map-set checkpoints 
              {account: current-delegate, checkpoint: current-checkpoints}
              {block-height: current-block, votes: new-current-votes})
            (map-set num-checkpoints current-delegate (+ current-checkpoints u1)))))
      
      ;; Add votes to new delegate
      (let ((new-delegate-votes (default-to u0 (map-get? delegate-count delegatee))))
        (let ((updated-votes (+ new-delegate-votes delegator-balance)))
          (map-set delegate-count delegatee updated-votes)
          ;; Write checkpoint for new delegate
          (let ((new-checkpoints (default-to u0 (map-get? num-checkpoints delegatee))))
            (map-set checkpoints 
              {account: delegatee, checkpoint: new-checkpoints}
              {block-height: current-block, votes: updated-votes})
            (map-set num-checkpoints delegatee (+ new-checkpoints u1)))))
      
      (print {event: "delegate-changed", delegator: delegator, from: current-delegate, to: delegatee})
      (ok true))))

;; Mint new tokens (self-contained)
(define-public (mint (recipient principal) (amount uint))
  (begin
    (asserts! (not (var-get paused)) ERR_PAUSED)
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (is-valid-principal recipient) ERR_INVALID_INPUT)
    
    ;; Mint tokens
    (try! (ft-mint? governance-token amount recipient))
    
    ;; Set initial delegation to self if not already set
    (if (is-none (map-get? delegates recipient))
        (map-set delegates recipient recipient)
        true)
    
    ;; Update voting power for recipient's delegate
    (let ((recipient-delegate (default-to recipient (map-get? delegates recipient)))
          (current-block stacks-block-height))
      (let ((current-votes (default-to u0 (map-get? delegate-count recipient-delegate))))
        (let ((new-votes (+ current-votes amount)))
          (map-set delegate-count recipient-delegate new-votes)
          ;; Write checkpoint
          (let ((checkpoints-count (default-to u0 (map-get? num-checkpoints recipient-delegate))))
            (map-set checkpoints 
              {account: recipient-delegate, checkpoint: checkpoints-count}
              {block-height: current-block, votes: new-votes})
            (map-set num-checkpoints recipient-delegate (+ checkpoints-count u1))))))
    
    (print {event: "mint", to: recipient, amount: amount})
    (ok true)))

;; Burn tokens (self-contained)
(define-public (burn (amount uint))
  (let ((sender tx-sender)
        (sender-delegate (default-to sender (map-get? delegates sender)))
        (current-block stacks-block-height))
    (begin
      (asserts! (not (var-get paused)) ERR_PAUSED)
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      
      ;; Burn tokens
      (try! (ft-burn? governance-token amount sender))
      
      ;; Update voting power
      (let ((current-votes (default-to u0 (map-get? delegate-count sender-delegate))))
        (let ((new-votes (if (>= current-votes amount) (- current-votes amount) u0)))
          (map-set delegate-count sender-delegate new-votes)
          ;; Write checkpoint
          (let ((checkpoints-count (default-to u0 (map-get? num-checkpoints sender-delegate))))
            (map-set checkpoints 
              {account: sender-delegate, checkpoint: checkpoints-count}
              {block-height: current-block, votes: new-votes})
            (map-set num-checkpoints sender-delegate (+ checkpoints-count u1)))))
      
      (print {event: "burn", from: sender, amount: amount})
      (ok true))))

;; Update token URI (only contract owner)
(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    ;; Validate URI
    (asserts! (is-valid-uri new-uri) ERR_INVALID_INPUT)
    (var-set token-uri new-uri)
    (print {event: "token-uri-updated", uri: new-uri})
    (ok true)))

;; Emergency withdrawal (only owner, when paused)
(define-public (emergency-withdraw (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (var-get paused) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (is-valid-principal recipient) ERR_INVALID_INPUT)
    (ft-transfer? governance-token amount tx-sender recipient)))