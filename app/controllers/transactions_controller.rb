# frozen_string_literal: true

class TransactionsController < AuthenticatedController
  include Pagy::Method

  before_action :set_transaction, only: %i[show edit update destroy]
  before_action :set_accounts, only: %i[index new edit create update]

  def index
    transactions = current_user.transactions.includes(:account).order(date: :desc, created_at: :desc)
    transactions = transactions.by_period(params[:start_date], params[:end_date]) if date_range_filter?
    transactions = transactions.search(params[:q]) if params[:q].present?
    transactions = transactions.where(transaction_type: params[:transaction_type]) if valid_transaction_type_filter?

    @pagy, @transactions = pagy(:offset, transactions, limit: 25)
  end

  def show
  end

  def new
    @transaction = Transaction.new(date: Date.current, transaction_type: "expense", status: "settled")
  end

  def edit
    prepare_transfer_form_transaction if @transaction.transfer?
  end

  def create
    if transfer_request?
      create_transfer
    else
      create_transaction
    end
  end

  def update
    return update_transfer if @transaction.transfer?

    if promotes_transaction_to_transfer?
      return render_existing_transaction_error(:transaction_type, :transfer_update_requires_new_record)
    end

    if amount_too_large?
      @transaction.assign_attributes(transaction_params.except(:amount))
      add_transaction_error(@transaction, :amount, :amount_too_large)
      return render :edit, status: :unprocessable_entity
    end

    account = current_user.accounts.find(transaction_account_id) if transaction_account_id.present?
    attributes = transaction_params
    attributes[:account] = account if account

    if @transaction.update(attributes)
      redirect_to transactions_path, notice: t("finance.transactions.notices.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    Transfers::Destroy.new.call(@transaction)
    redirect_to transactions_path, notice: t("finance.transactions.notices.destroyed")
  end

  private

  def set_transaction
    @transaction = current_user.transactions.find(params[:id])
  end

  def set_accounts
    @accounts = current_user.accounts.order(:name)
  end

  def create_transaction
    return render_transaction_error(:amount, :amount_too_large) if amount_too_large?

    account = current_user.accounts.find(transaction_account_id)
    @transaction = account.transactions.build(transaction_params)

    if @transaction.save
      redirect_to transactions_path, notice: t("finance.transactions.notices.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def create_transfer
    return render_transaction_error(:amount, :amount_too_large) if amount_too_large?
    return render_transaction_error(:to_account_id, :destination_required) if transfer_account_id.blank?

    from_account = current_user.accounts.find(transaction_account_id)
    to_account = current_user.accounts.find(transfer_account_id)

    Transfers::Create.new.call(
      from_account: from_account,
      to_account: to_account,
      amount: transaction_params[:amount],
      date: transaction_params[:date],
      description: transaction_params[:description],
      status: transaction_params[:status]
    )

    redirect_to transactions_path, notice: t("finance.transactions.notices.transfer_created")
  rescue Transfers::Create::SameAccountTransferError
    render_transaction_error(:to_account_id, :same_account_transfer)
  rescue ActiveRecord::RecordInvalid => error
    @transaction = build_form_transaction
    error.record.errors.each { |record_error| @transaction.errors.import(record_error) }
    render :new, status: :unprocessable_entity
  end

  def transaction_params
    @transaction_params ||= params.require(:transaction).permit(
      :description,
      :amount,
      :transaction_type,
      :date,
      :status
    )
  end

  def transaction_account_id
    params.require(:transaction)[:account_id].presence
  end

  def transfer_account_id
    params.require(:transaction)[:to_account_id].presence
  end

  def date_range_filter?
    params[:start_date].present? && params[:end_date].present?
  end

  def valid_transaction_type_filter?
    params[:transaction_type].present? && params[:transaction_type].in?(Transaction::TRANSACTION_TYPES)
  end

  def transfer_request?
    transaction_params[:transaction_type] == "transfer"
  end

  def promotes_transaction_to_transfer?
    transaction_params[:transaction_type] == "transfer"
  end

  def update_transfer
    return render_existing_transaction_error(:amount, :amount_too_large) if amount_too_large?
    return render_existing_transaction_error(:to_account_id, :destination_required) if transfer_account_id.blank?

    from_account = current_user.accounts.find(transaction_account_id)
    to_account = current_user.accounts.find(transfer_account_id)

    Transfers::Update.new.call(
      transaction: @transaction,
      from_account: from_account,
      to_account: to_account,
      amount: transaction_params[:amount],
      date: transaction_params[:date],
      description: transaction_params[:description],
      status: transaction_params[:status]
    )

    redirect_to transactions_path, notice: t("finance.transactions.notices.updated")
  rescue Transfers::Create::SameAccountTransferError
    render_existing_transaction_error(:to_account_id, :same_account_transfer)
  rescue Transfers::Update::MissingPairError
    render_not_found
  rescue ActiveRecord::RecordInvalid => error
    unless error.record.equal?(@transaction)
      error.record.errors.each { |record_error| @transaction.errors.import(record_error) }
    end
    prepare_transfer_form_transaction
    render :edit, status: :unprocessable_entity
  end

  def amount_too_large?
    raw_amount = params.require(:transaction)[:amount]
    return false if raw_amount.blank?

    BigDecimal(raw_amount.to_s) > Transaction::MAX_AMOUNT
  rescue ArgumentError
    false
  end

  def render_transaction_error(attribute, error_key)
    @transaction = build_form_transaction
    add_transaction_error(@transaction, attribute, error_key)
    render :new, status: :unprocessable_entity
  end

  def build_form_transaction
    Transaction.new(transaction_params.except(:amount)).tap do |transaction|
      transaction.amount = transaction_params[:amount] unless amount_too_large?
      transaction.account_id = transaction_account_id if transaction_account_id.present?
      transaction.to_account_id = transfer_account_id if transfer_account_id.present?
    end
  end

  def add_transaction_error(transaction, attribute, error_key)
    transaction.errors.add(
      attribute,
      t("finance.transactions.errors.#{error_key}", max: Transaction::MAX_AMOUNT.to_s("F"))
    )
  end

  def render_existing_transaction_error(attribute, error_key)
    attributes = transaction_params.except(:amount)
    attributes = attributes.except(:transaction_type) if error_key == :transfer_update_requires_new_record

    @transaction.assign_attributes(attributes)
    @transaction.amount = transaction_params[:amount] unless amount_too_large?
    @transaction.account_id = transaction_account_id if transaction_account_id.present?
    @transaction.to_account_id = transfer_account_id if transfer_account_id.present?
    add_transaction_error(@transaction, attribute, error_key)
    render :edit, status: :unprocessable_entity
  end

  def prepare_transfer_form_transaction
    pair = @transaction.transfer_pair
    return unless pair

    source, destination =
      if @transaction.transfer_direction == "incoming"
        [ pair, @transaction ]
      else
        [ @transaction, pair ]
      end

    @transaction.account_id = source.account_id
    @transaction.to_account_id = destination.account_id
  end
end
