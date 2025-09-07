;; Transfer Authorization Contract
;; Controls and logs land title transfers with digital signatures

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u200))
(define-constant ERR-PROPERTY-NOT-FOUND (err u201))
(define-constant ERR-TRANSFER-NOT-FOUND (err u202))
(define-constant ERR-INVALID-BUYER (err u203))
(define-constant ERR-INVALID-AMOUNT (err u204))
(define-constant ERR-TRANSFER-EXPIRED (err u205))
(define-constant ERR-TRANSFER-ALREADY-COMPLETED (err u206))
(define-constant ERR-INSUFFICIENT-ESCROW (err u207))
(define-constant ERR-INVALID-SIGNATURES (err u208))
(define-constant ERR-TRANSFER-NOT-AUTHORIZED (err u209))
(define-constant ERR-ESCROW-LOCKED (err u210))
(define-constant MIN-TRANSFER-AMOUNT u1000000)  ;; Minimum 1 STX in micro-STX
(define-constant TRANSFER-EXPIRY-BLOCKS u1008)  ;; ~1 week in blocks
(define-constant MAX-TRANSFER-ID u999999)

;; Data Variables
(define-data-var transfer-counter uint u0)
(define-data-var contract-admin principal CONTRACT-OWNER)
(define-data-var registry-contract principal CONTRACT-OWNER)
(define-data-var escrow-fee-rate uint u250)  ;; 2.5% fee in basis points

;; Transfer Request Map
(define-map transfer-requests
    uint
    {
        property-id: uint,
        seller: principal,
        buyer: principal,
        transfer-amount: uint,
        escrow-amount: uint,
        created-block: uint,
        expiry-block: uint,
        status: (string-ascii 20),
        seller-signature: (optional (buff 65)),
        buyer-signature: (optional (buff 65)),
        completion-date: (optional uint)
    }
)

;; Escrow balances for transfers
(define-map escrow-balances
    uint
    uint
)

;; Transfer history for audit trail
(define-map transfer-history
    uint
    {
        transfer-id: uint,
        previous-owner: principal,
        new-owner: principal,
        transfer-price: uint,
        completion-block: uint,
        witnesses: (list 5 principal)
    }
)

;; Authorized agents for transfers
(define-map authorized-agents
    principal
    bool
)

;; Property transfer logs
(define-map property-transfer-logs
    uint
    (list 20 uint)
)

;; Private Functions

;; Calculate escrow fee
(define-private (calculate-escrow-fee (amount uint))
    (/ (* amount (var-get escrow-fee-rate)) u10000)
)

;; Validate transfer amount
(define-private (is-valid-transfer-amount (amount uint))
    (>= amount MIN-TRANSFER-AMOUNT)
)

;; Check if transfer is expired
(define-private (is-transfer-expired (expiry-block uint))
    (> stacks-block-height expiry-block)
)

;; Add transfer to property logs
(define-private (add-to-property-logs (property-id uint) (transfer-id uint))
    (let (
        (current-logs (default-to (list) (map-get? property-transfer-logs property-id)))
    )
        (map-set property-transfer-logs property-id 
            (unwrap! (as-max-len? (append current-logs transfer-id) u20) (err u211))
        )
    )
)

;; Validate digital signatures (simplified)
(define-private (validate-signature (signature (buff 65)) (signer principal))
    ;; In a real implementation, this would verify cryptographic signatures
    ;; For this example, we'll assume signature is valid if present
    (is-some (some signature))
)

;; Public Functions

;; Initiate a property transfer
(define-public (initiate-transfer
    (property-id uint)
    (buyer principal)
    (transfer-amount uint)
)
    (let (
        (transfer-id (+ (var-get transfer-counter) u1))
        (current-block stacks-block-height)
        (expiry-block (+ current-block TRANSFER-EXPIRY-BLOCKS))
        (escrow-fee (calculate-escrow-fee transfer-amount))
        (total-escrow (+ transfer-amount escrow-fee))
    )
        ;; Validation checks
        (asserts! (is-valid-transfer-amount transfer-amount) ERR-INVALID-AMOUNT)
        (asserts! (not (is-eq tx-sender buyer)) ERR-INVALID-BUYER)
        (asserts! (<= transfer-id MAX-TRANSFER-ID) (err u212))
        
        ;; Create transfer request
        (map-set transfer-requests transfer-id
            {
                property-id: property-id,
                seller: tx-sender,
                buyer: buyer,
                transfer-amount: transfer-amount,
                escrow-amount: total-escrow,
                created-block: current-block,
                expiry-block: expiry-block,
                status: "pending",
                seller-signature: none,
                buyer-signature: none,
                completion-date: none
            }
        )
        
        ;; Initialize escrow balance
        (map-set escrow-balances transfer-id u0)
        
        ;; Add to property logs
        (unwrap! (add-to-property-logs property-id transfer-id) (err u213))
        
        ;; Update counter
        (var-set transfer-counter transfer-id)
        
        (ok transfer-id)
    )
)

;; Deposit escrow funds
(define-public (deposit-escrow (transfer-id uint) (amount uint))
    (let (
        (transfer-data (unwrap! (map-get? transfer-requests transfer-id) ERR-TRANSFER-NOT-FOUND))
        (current-escrow (default-to u0 (map-get? escrow-balances transfer-id)))
        (new-escrow (+ current-escrow amount))
    )
        ;; Validation checks
        (asserts! (is-eq tx-sender (get buyer transfer-data)) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status transfer-data) "pending") ERR-TRANSFER-ALREADY-COMPLETED)
        (asserts! (not (is-transfer-expired (get expiry-block transfer-data))) ERR-TRANSFER-EXPIRED)
        
        ;; Update escrow balance
        (map-set escrow-balances transfer-id new-escrow)
        
        ;; Check if sufficient escrow deposited
        (if (>= new-escrow (get escrow-amount transfer-data))
            (map-set transfer-requests transfer-id
                (merge transfer-data { status: "escrowed" })
            )
            true
        )
        
        (ok new-escrow)
    )
)

;; Sign transfer (seller or buyer)
(define-public (sign-transfer (transfer-id uint) (signature (buff 65)))
    (let (
        (transfer-data (unwrap! (map-get? transfer-requests transfer-id) ERR-TRANSFER-NOT-FOUND))
        (is-seller (is-eq tx-sender (get seller transfer-data)))
        (is-buyer (is-eq tx-sender (get buyer transfer-data)))
    )
        ;; Validation checks
        (asserts! (or is-seller is-buyer) ERR-UNAUTHORIZED)
        (asserts! (not (is-eq (get status transfer-data) "completed")) ERR-TRANSFER-ALREADY-COMPLETED)
        (asserts! (not (is-transfer-expired (get expiry-block transfer-data))) ERR-TRANSFER-EXPIRED)
        (asserts! (validate-signature signature tx-sender) ERR-INVALID-SIGNATURES)
        
        ;; Update signature based on signer
        (if is-seller
            (map-set transfer-requests transfer-id
                (merge transfer-data { seller-signature: (some signature) })
            )
            (map-set transfer-requests transfer-id
                (merge transfer-data { buyer-signature: (some signature) })
            )
        )
        
        (ok true)
    )
)

;; Complete transfer (requires both signatures and sufficient escrow)
(define-public (complete-transfer (transfer-id uint) (witnesses (list 5 principal)))
    (let (
        (transfer-data (unwrap! (map-get? transfer-requests transfer-id) ERR-TRANSFER-NOT-FOUND))
        (escrow-balance (default-to u0 (map-get? escrow-balances transfer-id)))
    )
        ;; Validation checks
        (asserts! (or 
            (is-eq tx-sender (get seller transfer-data)) 
            (is-eq tx-sender (get buyer transfer-data))
            (is-eq tx-sender (var-get contract-admin))
        ) ERR-UNAUTHORIZED)
        (asserts! (is-some (get seller-signature transfer-data)) ERR-INVALID-SIGNATURES)
        (asserts! (is-some (get buyer-signature transfer-data)) ERR-INVALID-SIGNATURES)
        (asserts! (>= escrow-balance (get escrow-amount transfer-data)) ERR-INSUFFICIENT-ESCROW)
        (asserts! (not (is-eq (get status transfer-data) "completed")) ERR-TRANSFER-ALREADY-COMPLETED)
        (asserts! (not (is-transfer-expired (get expiry-block transfer-data))) ERR-TRANSFER-EXPIRED)
        
        ;; Update transfer status
        (map-set transfer-requests transfer-id
            (merge transfer-data 
                { 
                    status: "completed",
                    completion-date: (some stacks-block-height)
                }
            )
        )
        
        ;; Record transfer history
        (map-set transfer-history transfer-id
            {
                transfer-id: transfer-id,
                previous-owner: (get seller transfer-data),
                new-owner: (get buyer transfer-data),
                transfer-price: (get transfer-amount transfer-data),
                completion-block: stacks-block-height,
                witnesses: witnesses
            }
        )
        
        ;; Release escrow to seller (minus fees)
        (let (
            (fee-amount (calculate-escrow-fee (get transfer-amount transfer-data)))
            (seller-amount (- (get transfer-amount transfer-data) fee-amount))
        )
            (map-set escrow-balances transfer-id u0)
            ;; In real implementation, would transfer STX to seller
            (ok seller-amount)
        )
    )
)

;; Cancel transfer (seller or admin only, before completion)
(define-public (cancel-transfer (transfer-id uint))
    (let (
        (transfer-data (unwrap! (map-get? transfer-requests transfer-id) ERR-TRANSFER-NOT-FOUND))
        (escrow-balance (default-to u0 (map-get? escrow-balances transfer-id)))
    )
        ;; Authorization check
        (asserts! (or 
            (is-eq tx-sender (get seller transfer-data))
            (is-eq tx-sender (var-get contract-admin))
            (is-transfer-expired (get expiry-block transfer-data))
        ) ERR-UNAUTHORIZED)
        (asserts! (not (is-eq (get status transfer-data) "completed")) ERR-TRANSFER-ALREADY-COMPLETED)
        
        ;; Update status to cancelled
        (map-set transfer-requests transfer-id
            (merge transfer-data { status: "cancelled" })
        )
        
        ;; Refund escrow to buyer if any deposited
        (if (> escrow-balance u0)
            (begin
                (map-set escrow-balances transfer-id u0)
                ;; In real implementation, would refund STX to buyer
                (ok escrow-balance)
            )
            (ok u0)
        )
    )
)

;; Authorize agent for transfers
(define-public (authorize-agent (agent principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-UNAUTHORIZED)
        (map-set authorized-agents agent true)
        (ok true)
    )
)

;; Read-only Functions

;; Get transfer details
(define-read-only (get-transfer-details (transfer-id uint))
    (map-get? transfer-requests transfer-id)
)

;; Get transfer status
(define-read-only (get-transfer-status (transfer-id uint))
    (match (map-get? transfer-requests transfer-id)
        transfer-data (some (get status transfer-data))
        none
    )
)

;; Get escrow balance for transfer
(define-read-only (get-escrow-balance (transfer-id uint))
    (map-get? escrow-balances transfer-id)
)

;; Get transfer history
(define-read-only (get-transfer-history (transfer-id uint))
    (map-get? transfer-history transfer-id)
)

;; Get property transfer logs
(define-read-only (get-property-transfers (property-id uint))
    (map-get? property-transfer-logs property-id)
)

;; Check if agent is authorized
(define-read-only (is-authorized-agent (agent principal))
    (default-to false (map-get? authorized-agents agent))
)

;; Get total transfers
(define-read-only (get-total-transfers)
    (var-get transfer-counter)
)

;; Check if transfer is expired
(define-read-only (is-expired (transfer-id uint))
    (match (map-get? transfer-requests transfer-id)
        transfer-data (is-transfer-expired (get expiry-block transfer-data))
        true
    )
)

;; Get current escrow fee rate
(define-read-only (get-escrow-fee-rate)
    (var-get escrow-fee-rate)
)

;; Calculate fee for amount
(define-read-only (get-escrow-fee (amount uint))
    (calculate-escrow-fee amount)
)

;; Admin Functions

;; Set escrow fee rate (admin only)
(define-public (set-escrow-fee-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-UNAUTHORIZED)
        (asserts! (<= new-rate u1000) (err u214))  ;; Max 10% fee
        (var-set escrow-fee-rate new-rate)
        (ok true)
    )
)

;; Set registry contract (admin only)
(define-public (set-registry-contract (new-registry principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-UNAUTHORIZED)
        (var-set registry-contract new-registry)
        (ok true)
    )
)

;; Set contract admin (admin only)
(define-public (set-contract-admin (new-admin principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-UNAUTHORIZED)
        (var-set contract-admin new-admin)
        (ok true)
    )
)

;; Get contract admin
(define-read-only (get-contract-admin)
    (var-get contract-admin)
)
