;; Land Title Registry Contract
;; Manages ownership records and land metadata for decentralized land registration

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-PROPERTY-EXISTS (err u101))
(define-constant ERR-PROPERTY-NOT-FOUND (err u102))
(define-constant ERR-INVALID-COORDINATES (err u103))
(define-constant ERR-INVALID-SIZE (err u104))
(define-constant ERR-INVALID-OWNER (err u105))
(define-constant MAX-PROPERTY-ID u999999)
(define-constant MIN-PROPERTY-SIZE u1)
(define-constant MAX-PROPERTY-SIZE u1000000000)

;; Data Maps and Variables
(define-data-var property-counter uint u0)
(define-data-var contract-admin principal CONTRACT-OWNER)

;; Property registry map - stores complete property information
(define-map properties
    uint
    {
        owner: principal,
        coordinates-x: int,
        coordinates-y: int,
        size-sqm: uint,
        legal-description: (string-ascii 500),
        registration-date: uint,
        last-updated: uint,
        property-type: (string-ascii 50),
        verified: bool
    }
)

;; Owner to properties mapping for quick lookup
(define-map owner-properties
    principal
    (list 100 uint)
)

;; Property address mapping for human-readable lookups
(define-map property-addresses
    (string-ascii 200)
    uint
)

;; Registration history for audit trail
(define-map registration-history
    uint
    {
        registered-by: principal,
        registration-block: uint,
        previous-owner: (optional principal)
    }
)

;; Private Functions

;; Validate coordinates are within reasonable bounds
(define-private (is-valid-coordinates (x int) (y int))
    (and 
        (>= x -180000000) (<= x 180000000)  ;; longitude bounds * 1000000 for precision
        (>= y -90000000) (<= y 90000000)    ;; latitude bounds * 1000000 for precision
    )
)

;; Validate property size is within acceptable range
(define-private (is-valid-size (size uint))
    (and (>= size MIN-PROPERTY-SIZE) (<= size MAX-PROPERTY-SIZE))
)

;; Add property to owner's property list
(define-private (add-to-owner-properties (owner principal) (property-id uint))
    (let (
        (current-properties (default-to (list) (map-get? owner-properties owner)))
    )
        (map-set owner-properties owner (unwrap! (as-max-len? (append current-properties property-id) u100) (err u106)))
    )
)

;; Remove property from owner's property list
(define-private (remove-from-owner-properties (owner principal) (property-id uint))
    (let (
        (current-properties (default-to (list) (map-get? owner-properties owner)))
    )
        (map-set owner-properties owner 
            (filter (lambda (id) (not (is-eq id property-id))) current-properties)
        )
        (ok true)
    )
)

;; Public Functions

;; Register a new property
(define-public (register-property
    (coordinates-x int)
    (coordinates-y int)
    (size-sqm uint)
    (legal-description (string-ascii 500))
    (property-type (string-ascii 50))
    (address (string-ascii 200))
)
    (let (
        (property-id (+ (var-get property-counter) u1))
        (current-block stacks-block-height)
    )
        ;; Validation checks
        (asserts! (is-valid-coordinates coordinates-x coordinates-y) ERR-INVALID-COORDINATES)
        (asserts! (is-valid-size size-sqm) ERR-INVALID-SIZE)
        (asserts! (is-none (map-get? property-addresses address)) ERR-PROPERTY-EXISTS)
        (asserts! (<= property-id MAX-PROPERTY-ID) (err u107))
        
        ;; Store property data
        (map-set properties property-id
            {
                owner: tx-sender,
                coordinates-x: coordinates-x,
                coordinates-y: coordinates-y,
                size-sqm: size-sqm,
                legal-description: legal-description,
                registration-date: current-block,
                last-updated: current-block,
                property-type: property-type,
                verified: false
            }
        )
        
        ;; Store address mapping
        (map-set property-addresses address property-id)
        
        ;; Store registration history
        (map-set registration-history property-id
            {
                registered-by: tx-sender,
                registration-block: current-block,
                previous-owner: none
            }
        )
        
        ;; Add to owner's property list
        (unwrap! (add-to-owner-properties tx-sender property-id) (err u108))
        
        ;; Update counter
        (var-set property-counter property-id)
        
        (ok property-id)
    )
)

;; Update property ownership (for transfers)
(define-public (update-property-owner (property-id uint) (new-owner principal))
    (let (
        (property-data (unwrap! (map-get? properties property-id) ERR-PROPERTY-NOT-FOUND))
        (current-owner (get owner property-data))
    )
        ;; Only current owner or contract admin can transfer
        (asserts! (or (is-eq tx-sender current-owner) (is-eq tx-sender (var-get contract-admin))) ERR-UNAUTHORIZED)
        
        ;; Update property ownership
        (map-set properties property-id
            (merge property-data
                {
                    owner: new-owner,
                    last-updated: stacks-block-height
                }
            )
        )
        
        ;; Update owner property lists
        (unwrap! (remove-from-owner-properties current-owner property-id) (err u110))
        (unwrap! (add-to-owner-properties new-owner property-id) (err u109))
        
        ;; Update registration history
        (map-set registration-history property-id
            {
                registered-by: tx-sender,
                registration-block: stacks-block-height,
                previous-owner: (some current-owner)
            }
        )
        
        (ok true)
    )
)

;; Verify property (admin only)
(define-public (verify-property (property-id uint))
    (let (
        (property-data (unwrap! (map-get? properties property-id) ERR-PROPERTY-NOT-FOUND))
    )
        (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-UNAUTHORIZED)
        
        (map-set properties property-id
            (merge property-data { verified: true, last-updated: stacks-block-height })
        )
        
        (ok true)
    )
)

;; Update property details (owner only)
(define-public (update-property-details
    (property-id uint)
    (legal-description (string-ascii 500))
    (property-type (string-ascii 50))
)
    (let (
        (property-data (unwrap! (map-get? properties property-id) ERR-PROPERTY-NOT-FOUND))
    )
        (asserts! (is-eq tx-sender (get owner property-data)) ERR-UNAUTHORIZED)
        
        (map-set properties property-id
            (merge property-data
                {
                    legal-description: legal-description,
                    property-type: property-type,
                    last-updated: stacks-block-height
                }
            )
        )
        
        (ok true)
    )
)

;; Read-only Functions

;; Get property details
(define-read-only (get-property-details (property-id uint))
    (map-get? properties property-id)
)

;; Get property by address
(define-read-only (get-property-by-address (address (string-ascii 200)))
    (match (map-get? property-addresses address)
        property-id (map-get? properties property-id)
        none
    )
)

;; Get properties owned by principal
(define-read-only (get-owner-properties (owner principal))
    (map-get? owner-properties owner)
)

;; Get property owner
(define-read-only (get-property-owner (property-id uint))
    (match (map-get? properties property-id)
        property-data (some (get owner property-data))
        none
    )
)

;; Get total registered properties
(define-read-only (get-total-properties)
    (var-get property-counter)
)

;; Get registration history
(define-read-only (get-registration-history (property-id uint))
    (map-get? registration-history property-id)
)

;; Check if property exists
(define-read-only (property-exists (property-id uint))
    (is-some (map-get? properties property-id))
)

;; Get property verification status
(define-read-only (is-property-verified (property-id uint))
    (match (map-get? properties property-id)
        property-data (get verified property-data)
        false
    )
)

;; Admin function to update contract admin
(define-public (set-contract-admin (new-admin principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-UNAUTHORIZED)
        (var-set contract-admin new-admin)
        (ok true)
    )
)

;; Get current contract admin
(define-read-only (get-contract-admin)
    (var-get contract-admin)
)
