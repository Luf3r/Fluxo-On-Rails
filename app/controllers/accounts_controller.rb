# frozen_string_literal: true

class AccountsController < AuthenticatedController
  before_action :set_account, only: %i[show edit update destroy balance]

  def index
    @accounts = current_user.accounts.order(:name)
  end

  def show
    @recent_transactions = @account.transactions.order(date: :desc, created_at: :desc).limit(8)
  end

  def new
    @account = current_user.accounts.build(currency: current_user.currency, initial_balance: 0)
  end

  def edit
  end

  def create
    @account = current_user.accounts.build(account_params)

    if initial_balance_too_large?
      add_initial_balance_error(@account)
      render :new, status: :unprocessable_entity
    elsif @account.save
      redirect_to @account, notice: t("finance.accounts.notices.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if initial_balance_too_large?
      @account.assign_attributes(account_params.except(:initial_balance))
      add_initial_balance_error(@account)
      render :edit, status: :unprocessable_entity
    elsif @account.update(account_params)
      redirect_to @account, notice: t("finance.accounts.notices.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @account.destroy!
    redirect_to accounts_path, notice: t("finance.accounts.notices.destroyed")
  end

  def balance
    render plain: helpers.finance_money(@account.current_balance, @account.currency)
  end

  private

  def set_account
    @account = current_user.accounts.find(params[:id])
  end

  def account_params
    params.require(:account).permit(:name, :account_type, :currency, :initial_balance)
  end

  def initial_balance_too_large?
    raw_initial_balance = params.require(:account)[:initial_balance]
    return false if raw_initial_balance.blank?

    BigDecimal(raw_initial_balance.to_s) > Account::MAX_INITIAL_BALANCE
  rescue ArgumentError
    false
  end

  def add_initial_balance_error(account)
    account.errors.add(
      :initial_balance,
      t("finance.accounts.errors.initial_balance_too_large", max: Account::MAX_INITIAL_BALANCE.to_s("F"))
    )
  end
end
