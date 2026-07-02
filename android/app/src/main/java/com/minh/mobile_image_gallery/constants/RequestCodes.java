package com.minh.mobile_image_gallery.constants;

abstract public class RequestCodes {
    public static final int DELETE_REQUEST_CODE = 100;

    public static final int CREATE_ALBUM_REQUEST_CODE = 200;

    public static final int MOVE_MEDIA_TO_TRASH = 300;

    // delete-consent for the originals after a move
    public static final int MOVE_DELETE_REQUEST_CODE = 400;

    // SAF folder grant for moving into a non-standard folder
    public static final int SAF_TREE_REQUEST_CODE = 500;

}
