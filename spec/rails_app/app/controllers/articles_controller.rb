# frozen_string_literal: true

class ArticlesController < ApplicationController
  skip_before_action :verify_authenticity_token

  def index
    @articles = Article.search(search_params)
    render json: @articles
  end

  def show
    @article = Article.find(params[:id])
    render json: @article
  end

  def create
    @article = Article.create!(article_params)
    render json: @article, status: :created
  end

  def update
    @article = Article.find(params[:id])
    @article.update!(article_params)
    render json: @article
  end

  def destroy
    @article = Article.find(params[:id])
    @article.destroy
    head :no_content
  end

  def archive
    @article = Article.find(params[:id])
    @article.archive!(reason: params[:reason])
    render json: @article
  end

  def restore
    @article = Article.find(params[:id])
    @article.restore!
    render json: @article
  end

  private

  def search_params
    params.permit(:title_cont, :status_eq, :archived_at_present, :archived_at_null).to_h.symbolize_keys
  end

  def article_params
    params.permit(:title, :content, :status, :published_at, :expires_at, :view_count, :featured, tags: [])
  end
end
