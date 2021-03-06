class UsersController < ApplicationController
  skip_before_action :authorize, only: [:new, :create]

  before_action :set_user, only: [:update, :destroy]
  before_action :ensure_permission, only: [:update, :destroy]

  def new
    @user = User.new().with_params(params)
  end

  def create
    @user = User.new(user_params).with_params(user_params)
    if @user.save
      Librato.increment('user.trial.signup')
      @analytics_event = {eventCategory: 'customer', eventAction: 'new', eventLabel: 'trial', eventValue: 0}
      flash[:analytics_event] = render_to_string(partial: "shared/analytics_event").html_safe
      flash[:one_time_content] = render_to_string(partial: "shared/register_protocol_handlers").html_safe
      sign_in @user
      redirect_to root_url
    else
      render "new"
    end
  end

  def update
    old_plan_name = @user.plan.stripe_id
    @user.update_auth_token = true
    @user.old_password_valid = @user.authenticate(params[:user][:old_password])
    @user.attributes = user_params
    if params[:user] && params[:user][:password]
      @user.password_confirmation = params[:user][:password]
    end
    if @user.save
      new_plan_name = @user.plan.stripe_id
      if old_plan_name == 'trial' && new_plan_name != 'trial'
        Librato.increment('user.paid.signup')
        @analytics_event = {eventCategory: 'customer', eventAction: 'upgrade', eventLabel: @user.plan.stripe_id, eventValue: @user.plan.price.to_i}
        flash[:analytics_event] = render_to_string(partial: "shared/analytics_event").html_safe
      end
      sign_in @user
      if params[:redirect_to]
        redirect_to params[:redirect_to], notice: 'Account updated.'
      else
        redirect_to settings_account_path, notice: 'Account updated.'
      end
    else
      redirect_to settings_account_path, alert: @user.errors.full_messages.join('. ') + '.'
    end
  end

  def destroy
    @user.destroy
    redirect_to root_url
  end

  private

  def set_user
    @user = current_user
  end

  def ensure_permission
    unless @user.id == current_user.id
      render_404
    end
  end

  def user_params
    params.require(:user).permit(:email, :password, :stripe_token, :coupon_code, :plan_id)
  end


end
